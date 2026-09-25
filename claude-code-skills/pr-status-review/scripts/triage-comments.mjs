#!/usr/bin/env node
/**
 * Triage unanswered comments on your open PRs with TypeSafe's Jev model.
 *
 * Usage:
 *   node triage.mjs [--dry-run] [--limit N] [--repo owner/name] [--out file.md]
 *                   [--since YYYY-MM-DD] [--summary] [--ci]
 *
 * --summary prints per-PR counts as JSON on stdout instead of writing the
 * report, for callers that fold the counts into their own table.
 *
 * --ci also asks Jev why each failing check on a PR's head commit failed
 * (the PR's own bug, a flaky test, CI infrastructure, the base branch, or a
 * metadata check), from the check summary and an excerpt of its job log.
 *
 * Comments older than --since (default: 90 days ago) are grouped into a
 * stale-PR list at the end of the report.
 *
 * Requires `gh` (authenticated) and, unless --dry-run, TYPESAFE_API_KEY.
 * Private repositories are always skipped so their content never leaves GitHub.
 */
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const args = process.argv.slice( 2 );
const flag = ( name ) => args.includes( name );
const option = ( name ) => {
	const index = args.indexOf( name );
	return index === -1 ? undefined : args[ index + 1 ];
};

const DRY_RUN = flag( '--dry-run' );
const SUMMARY = flag( '--summary' );
const CI = flag( '--ci' );
const LIMIT = Number( option( '--limit' ) ?? 300 );
const DAY = 24 * 60 * 60 * 1000;
const SINCE =
	option( '--since' ) ??
	new Date( Date.now() - 90 * DAY ).toISOString().slice( 0, 10 );
const REPO = option( '--repo' );
const TODAY = new Date().toISOString().slice( 0, 10 );
const OUT =
	option( '--out' ) ??
	join( homedir(), 'Downloads', `pr-comment-triage-${ TODAY }.md` );
const CONCURRENCY = 6;
const MAX_BODY = 2000;
const MAX_LOG = 6000;
const MAX_LINE = 500;
const MAX_CHECKS = 5;
const API_URL = 'https://api.typesafe.ai/v1/systemone';

if ( ! DRY_RUN && ! process.env.TYPESAFE_API_KEY ) {
	console.error( 'TYPESAFE_API_KEY is not set. Use --dry-run to test without it.' );
	process.exit( 1 );
}

const gh = ( ...ghArgs ) =>
	execFileSync( 'gh', ghArgs, {
		encoding: 'utf8',
		maxBuffer: 64 * 1024 * 1024,
	} );

const ghAsync = ( ...ghArgs ) =>
	promisify( execFile )( 'gh', ghArgs, { maxBuffer: 64 * 1024 * 1024 } );

const ME = gh( 'api', 'user', '--jq', '.login' ).trim();

const PRS_PER_QUERY = 10;

const PAGE_INFO = 'pageInfo { hasPreviousPage startCursor }';

const COMMENT_FIELDS = 'nodes { author { __typename login } body createdAt url }';

const threadComments = ( before ) =>
  `comments(last: 20${
    before ? `, before: ${ JSON.stringify( before ) }` : ''
  }) { ${ PAGE_INFO } ${ COMMENT_FIELDS } }`;

// Feedback connections, newest page first. Longer histories are paged back
// by fetchOlderPages() so nothing unanswered falls off the end.
const CONNECTIONS = {
  reviewThreads: `nodes {
      id
      isResolved
      isOutdated
      path
      ${ threadComments() }
    }`,
  reviews: 'nodes { author { __typename login } state body submittedAt url }',
  comments: COMMENT_FIELDS,
};

const connection = ( name, before ) =>
  `${ name }(last: 100${
    before ? `, before: ${ JSON.stringify( before ) }` : ''
  }) { ${ PAGE_INFO } ${ CONNECTIONS[ name ] } }`;

// The head commit's checks and the files they might implicate, for --ci.
// Both connections page forward through fetchCiPages().
const NEXT_PAGE = 'pageInfo { hasNextPage endCursor }';

const after = ( cursor ) =>
  cursor ? `, after: ${ JSON.stringify( cursor ) }` : '';

const filesConnection = ( cursor ) =>
  `files(first: 100${ after( cursor ) }) { ${ NEXT_PAGE } nodes { path } }`;

const contextsConnection = ( cursor ) =>
  `commits(last: 1) { nodes { commit { statusCheckRollup { state contexts(first: 100${ after(
    cursor
  ) }) { ${ NEXT_PAGE } nodes {
    __typename
    ... on CheckRun {
      name conclusion detailsUrl databaseId title summary
      checkSuite { app { slug } workflowRun { workflow { name } } }
    }
    ... on StatusContext { context state targetUrl description }
  } } } } } }`;

const CI_FIELDS = `
  baseRefName
  ${ filesConnection() }
  ${ contextsConnection() }`;

const PR_FRAGMENT = `
fragment PendingConversation on PullRequest {
  title
  url
  ${ CI ? CI_FIELDS : '' }
  ${ Object.keys( CONNECTIONS )
    .map( ( name ) => connection( name ) )
    .join( '\n  ' ) }
}`;

/**
 * Build one GraphQL query that fetches several PRs through aliases.
 *
 * @param {Array} batch PRs from `gh search prs`.
 * @return {string} Query text.
 */
const batchQuery = ( batch ) =>
	`query {\n${ batch
		.map( ( { number, repository }, index ) => {
			const [ owner, name ] = repository.nameWithOwner.split( '/' );
			return `  pr${ index }: repository(owner: ${ JSON.stringify(
				owner
			) }, name: ${ JSON.stringify(
				name
			) }) { isPrivate pullRequest(number: ${ number }) { ...PendingConversation } }`;
		} )
		.join( '\n' ) }\n}\n${ PR_FRAGMENT }`;

let failures = 0;

/**
 * Prepend older pages to any feedback connection that did not fit in one page.
 *
 * @param {string} nameWithOwner Repository, as owner/name.
 * @param {number} number        PR number.
 * @param {Object} pr            GraphQL pullRequest node, updated in place.
 */
async function fetchOlderPages( nameWithOwner, number, pr ) {
	const [ owner, name ] = nameWithOwner.split( '/' );
	for ( const key of Object.keys( CONNECTIONS ) ) {
		while ( pr[ key ].pageInfo.hasPreviousPage ) {
			const { stdout } = await ghAsync(
				'api',
				'graphql',
				'-f',
				`query=query { repository(owner: ${ JSON.stringify(
					owner
				) }, name: ${ JSON.stringify(
					name
				) }) { pullRequest(number: ${ number }) { ${ connection(
					key,
					pr[ key ].pageInfo.startCursor
				) } } } }`
			);
			const page = JSON.parse( stdout ).data.repository.pullRequest[ key ];
			pr[ key ] = {
				pageInfo: page.pageInfo,
				nodes: [ ...page.nodes, ...pr[ key ].nodes ],
			};
		}
	}
	// Long unresolved threads can hide an unanswered request behind later replies.
	for ( const thread of pr.reviewThreads.nodes ) {
		while ( ! thread.isResolved && thread.comments.pageInfo.hasPreviousPage ) {
			const { stdout } = await ghAsync(
				'api',
				'graphql',
				'-f',
				`query=query { node(id: ${ JSON.stringify(
					thread.id
				) }) { ... on PullRequestReviewThread { ${ threadComments(
					thread.comments.pageInfo.startCursor
				) } } } }`
			);
			const page = JSON.parse( stdout ).data.node.comments;
			thread.comments = {
				pageInfo: page.pageInfo,
				nodes: [ ...page.nodes, ...thread.comments.nodes ],
			};
		}
	}
}

/**
 * Append later pages of a PR's head-commit checks and, when a check failed,
 * its changed files, so neither is cut off before failingChecks() runs.
 *
 * @param {string} nameWithOwner Repository, as owner/name.
 * @param {number} number        PR number.
 * @param {Object} pr            GraphQL pullRequest node, updated in place.
 */
async function fetchCiPages( nameWithOwner, number, pr ) {
	const [ owner, name ] = nameWithOwner.split( '/' );
	const page = async ( fields ) => {
		const { stdout } = await ghAsync(
			'api',
			'graphql',
			'-f',
			`query=query { repository(owner: ${ JSON.stringify(
				owner
			) }, name: ${ JSON.stringify(
				name
			) }) { pullRequest(number: ${ number }) { ${ fields } } } }`
		);
		return JSON.parse( stdout ).data.repository.pullRequest;
	};
	const rollup = pr.commits?.nodes[ 0 ]?.commit.statusCheckRollup;
	if ( ! rollup || ! FAILED.has( rollup.state ) ) {
		return;
	}
	while ( rollup.contexts.pageInfo.hasNextPage ) {
		const { contexts } = ( await page(
			contextsConnection( rollup.contexts.pageInfo.endCursor )
		) ).commits.nodes[ 0 ].commit.statusCheckRollup;
		rollup.contexts = {
			pageInfo: contexts.pageInfo,
			nodes: [ ...rollup.contexts.nodes, ...contexts.nodes ],
		};
	}
	while ( pr.files.pageInfo.hasNextPage ) {
		const { files } = await page(
			filesConnection( pr.files.pageInfo.endCursor )
		);
		pr.files = {
			pageInfo: files.pageInfo,
			nodes: [ ...pr.files.nodes, ...files.nodes ],
		};
	}
}

// Automated reviewers whose inline findings are worth classifying. Every
// other bot, and these bots' summary comments, are dropped before Jev.
const REVIEW_BOTS = new Set( [
	'coderabbitai',
	'copilot-pull-request-reviewer',
	'chatgpt-codex-connector',
	'gemini-code-assist',
] );

const isBot = ( node ) => node.author?.__typename === 'Bot';

const QUESTIONS = {
	category: {
		type: 'choice',
		instructions:
			'Classify the latest comment in this pull request conversation, from the point of view of the PR author who must decide whether to act on it.',
		criteria: {
			actionable_change:
				'Requests a specific code, test, or documentation change the author should make.',
			question:
				'Asks the author a question or for clarification, without clearly requesting a change.',
			nit: 'A minor, optional style or wording suggestion.',
			approval: 'Approves, praises, or says the change looks good.',
			bot_noise:
				'Automated output such as size reports, preview links, CI summaries, or dependency bot messages with nothing for the author to do.',
			bot_finding:
				'An automated reviewer (CodeRabbit, Copilot, etc.) reporting a specific possible bug or change.',
			status_update:
				'Informational update, cross-reference, or discussion that needs no response from the author.',
		},
	},
	needs_reply: {
		type: 'noul',
		instructions:
			'The PR author is expected to reply to or act on the latest comment.',
	},
	blocking: {
		type: 'noul',
		instructions:
			'The commenter is blocking merge or requesting changes they want addressed before the PR can land.',
	},
};

const CI_QUESTIONS = {
	cause: {
		type: 'choice',
		instructions:
			'Classify why this CI check failed on the pull request, from the point of view of the PR author deciding what to do about it.',
		criteria: {
			real_failure:
				"The PR's own changes caused it: a failing test, lint, type, or build error in code or tests the PR touches or depends on.",
			flaky_test:
				'A test that fails nondeterministically, such as a timeout waiting for the UI, a race, or an intermittent end-to-end assertion unrelated to the change.',
			infrastructure:
				'CI infrastructure trouble: a lost runner, network or package registry errors, rate limits, cache or artifact failures, or a cancelled or out-of-disk job.',
			base_branch:
				'Broken on the base branch or caused by an outdated branch: failures in code the PR does not touch, or that need a merge from the base branch.',
			process_check:
				'A policy or metadata check, such as a missing label, milestone, changelog entry, or PR description requirement, fixed without changing code.',
		},
	},
	rerun_passes: {
		type: 'noul',
		instructions:
			'Re-running this check without changing any code would likely make it pass.',
	},
};

// What each cause asks of the author, most demanding first, so a PR with
// mixed failures reports the step that actually unblocks it.
const CI_ACTIONS = [
	[ 'real_failure', 'fix' ],
	[ 'base_branch', 'update branch' ],
	[ 'process_check', 'fix metadata' ],
	[ 'flaky_test', 'rerun' ],
	[ 'infrastructure', 'rerun' ],
];

const FAILED = new Set( [
	'FAILURE',
	'TIMED_OUT',
	'STARTUP_FAILURE',
	'ERROR',
	'CANCELLED',
	'ACTION_REQUIRED',
] );

// Failed-test lines from Vitest, Jest, Playwright, and PHPUnit.
const FAILED_TEST = /^\s*(×|✕|✘|FAIL\s|\d+\) \[|\d+\) \w+.*::)|\(\d+ tests? \| \d+ failed\)/;

/**
 * List the failing checks on a PR's head commit, one per workflow and job.
 *
 * @param {Object} pr GraphQL pullRequest node fetched with CI_FIELDS.
 * @return {Array} Failing checks, at most MAX_CHECKS.
 */
function failingChecks( pr ) {
	const rollup = pr.commits?.nodes[ 0 ]?.commit.statusCheckRollup;
	if ( ! rollup || ! FAILED.has( rollup.state ) ) {
		return [];
	}
	// Keyed by workflow as well as name, so same-named jobs in different
	// workflows each get a row while reruns of one job collapse to one.
	const byName = new Map();
	for ( const node of rollup.contexts.nodes ) {
		if ( node.__typename === 'CheckRun' && FAILED.has( node.conclusion ) ) {
			const workflow =
				node.checkSuite?.workflowRun?.workflow.name ??
				node.checkSuite?.app?.slug;
			byName.set( `${ workflow }/${ node.name }`, {
				name: node.name,
				workflow,
				conclusion: node.conclusion,
				url: node.detailsUrl,
				// Actions check runs share their id with the job, which has the log.
				jobId:
					node.checkSuite?.app?.slug === 'github-actions'
						? node.databaseId
						: null,
				details: [ node.title, node.summary ].filter( Boolean ).join( '\n' ),
			} );
		} else if ( node.__typename === 'StatusContext' && FAILED.has( node.state ) ) {
			byName.set( `status/${ node.context }`, {
				name: node.context,
				conclusion: node.state,
				url: node.targetUrl,
				jobId: null,
				details: node.description ?? '',
			} );
		}
	}
	return [ ...byName.values() ].slice( 0, MAX_CHECKS );
}

/**
 * Cut a job log down to the lines that explain the failure.
 *
 * Post-job cleanup fills the end of every log, so the excerpt anchors on the
 * runner's `##[error]` markers and the step they belong to instead of the tail.
 *
 * @param {string} log Raw job log.
 * @return {Object} The failing step's name and the excerpt.
 */
function logExcerpt( log ) {
	let lines = log
		.split( '\n' )
		.map( ( line ) =>
			line
				.replace( /^\d{4}-\d\d-\d\dT[\d:.]+Z ?/, '' )
				.replace( /\x1b\[[0-9;]*m/g, '' )
		);
	const cleanup = lines.findIndex( ( line ) => line.startsWith( 'Post job cleanup' ) );
	if ( cleanup > 0 ) {
		lines = lines.slice( 0, cleanup );
	}
	const errors = lines
		.map( ( line, index ) => ( line.startsWith( '##[error]' ) ? index : -1 ) )
		.filter( ( index ) => index !== -1 );
	const first = errors[ 0 ] ?? lines.length;
	const step = lines
		.slice( 0, first )
		.findLast( ( line ) => line.startsWith( '##[group]Run ' ) )
		?.slice( '##[group]Run '.length );
	// Most telling lines first, so the MAX_LOG budget drops the context
	// farthest from an error rather than the failures themselves.
	const ranked = [
		...lines
			.map( ( line, index ) => ( FAILED_TEST.test( line ) ? index : -1 ) )
			.filter( ( index ) => index !== -1 && index < first )
			.slice( 0, 20 ),
		...errors.slice( 0, 3 ),
	];
	for ( let distance = 1; distance <= 40; distance++ ) {
		for ( const index of errors.slice( 0, 3 ) ) {
			ranked.push( index - distance );
		}
	}
	if ( ! errors.length ) {
		for ( let i = lines.length - 1; i >= lines.length - 60; i-- ) {
			ranked.push( i );
		}
	}
	const keep = new Set();
	let size = 0;
	for ( const index of ranked ) {
		const line = lines[ index ]?.slice( 0, MAX_LINE );
		if (
			line === undefined ||
			keep.has( index ) ||
			/^##\[(end)?group\]$/.test( line ) ||
			size + line.length + 1 > MAX_LOG
		) {
			continue;
		}
		keep.add( index );
		size += line.length + 1;
	}
	return {
		step,
		excerpt: [ ...keep ]
			.sort( ( a, b ) => a - b )
			.map( ( i ) => lines[ i ].slice( 0, MAX_LINE ) )
			.join( '\n' ),
	};
}

const clip = ( text ) =>
	text.length > MAX_BODY ? `${ text.slice( 0, MAX_BODY ) }…` : text;

const login = ( node ) => node.author?.login ?? 'ghost';

let droppedBots = 0;

/**
 * Collect the conversation items on one PR that are waiting on the author.
 *
 * @param {Object} pr GraphQL pullRequest node.
 * @return {Array} Items with the text Jev evaluates.
 */
function pendingItems( pr ) {
	const items = [];

	// Every inline comment after the author's last reply in its thread, so a
	// trailing thank-you can't hide the change request before it.
	for ( const thread of pr.reviewThreads.nodes ) {
		if ( thread.isResolved ) {
			continue;
		}
		const comments = thread.comments.nodes;
		const lastMine = comments.findLastIndex( ( c ) => login( c ) === ME );
		comments.forEach( ( comment, index ) => {
			if ( index <= lastMine ) {
				return;
			}
			if ( isBot( comment ) && ! REVIEW_BOTS.has( login( comment ) ) ) {
				droppedBots++;
				return;
			}
			items.push( {
				kind: thread.isOutdated ? 'review thread (outdated)' : 'review thread',
				author: login( comment ),
				url: comment.url,
				date: comment.createdAt,
				excerpt: comment.body,
				state: {
					pull_request: pr.title,
					file: thread.path,
					pr_author: ME,
					earlier_comments: comments
						.slice( Math.max( 0, index - 3 ), index )
						.map( ( c ) => ( { author: login( c ), body: clip( c.body ) } ) ),
					latest_comment: {
						author: login( comment ),
						body: clip( comment.body ),
					},
				},
			} );
		} );
	}

	// Top-level comments and review summaries after the author's last word.
	const timeline = [
		...pr.comments.nodes.map( ( c ) => ( { ...c, date: c.createdAt } ) ),
		...pr.reviews.nodes
			.filter( ( r ) => r.body?.trim() || r.state === 'CHANGES_REQUESTED' )
			.map( ( r ) => ( {
				...r,
				date: r.submittedAt,
				body: `[review: ${ r.state }] ${ r.body }`,
			} ) ),
	].sort( ( a, b ) => a.date.localeCompare( b.date ) );

	const lastMine = timeline.findLastIndex( ( c ) => login( c ) === ME );
	const afterMine = timeline.slice( lastMine + 1 );
	const recent = afterMine.filter( ( c ) => ! isBot( c ) );
	droppedBots += afterMine.length - recent.length;
	recent.forEach( ( comment, index ) => {
		items.push( {
			kind: 'conversation',
			author: login( comment ),
			url: comment.url,
			date: comment.date,
			excerpt: comment.body,
			state: {
				pull_request: pr.title,
				pr_author: ME,
				earlier_comments: recent.slice( Math.max( 0, index - 2 ), index ).map(
					( c ) => ( { author: login( c ), body: clip( c.body ) } )
				),
				latest_comment: {
					author: login( comment ),
					body: clip( comment.body ),
				},
			},
		} );
	} );

	return items;
}

async function askJev( state, questions = QUESTIONS ) {
	// One deadline across retries, so a stalled request can't hold up the run.
	const signal = AbortSignal.timeout( 60_000 );
	for ( let attempt = 0; ; attempt++ ) {
		const response = await fetch( API_URL, {
			signal,
			method: 'POST',
			headers: {
				Authorization: `Bearer ${ process.env.TYPESAFE_API_KEY }`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify( {
				model: 'jev-latest',
				state,
				questions,
			} ),
		} );
		if ( response.ok ) {
			return response.json();
		}
		if ( ( response.status === 429 || response.status === 529 ) && attempt < 5 ) {
			await new Promise( ( r ) => setTimeout( r, 500 * 2 ** attempt ) );
			continue;
		}
		throw new Error( `Jev ${ response.status }: ${ await response.text() }` );
	}
}

async function pool( list, worker ) {
	const results = new Array( list.length );
	let next = 0;
	await Promise.all(
		Array.from( { length: CONCURRENCY }, async () => {
			while ( next < list.length ) {
				const index = next++;
				results[ index ] = await worker( list[ index ], index );
			}
		} )
	);
	return results;
}

const searchArgs = [
	'search',
	'prs',
	'--author',
	'@me',
	'--state',
	'open',
	'--limit',
	String( LIMIT ),
	'--json',
	'number,repository',
];
if ( REPO ) {
	searchArgs.push( '--repo', REPO );
}
const prs = JSON.parse( gh( ...searchArgs ) );
console.error( `Fetching conversations for ${ prs.length } open PRs…` );

const batches = [];
for ( let i = 0; i < prs.length; i += PRS_PER_QUERY ) {
	batches.push( prs.slice( i, i + PRS_PER_QUERY ) );
}

let skippedPrivate = 0;
const ciItems = [];
// Every PR that loaded, so the summary can say which ones were never triaged.
const coverage = [];
const perBatch = await pool( batches, async ( batch ) => {
	let output;
	try {
		( { stdout: output } = await ghAsync(
			'api',
			'graphql',
			'-f',
			`query=${ batchQuery( batch ) }`
		) );
	} catch ( error ) {
		// gh exits non-zero when any alias errors, but still prints the rest.
		output = error.stdout;
		console.error( `  batch error: ${ error.stderr?.trim() || error.message }` );
	}
	const data = output ? JSON.parse( output ).data ?? {} : {};
	const items = [];
	for ( const [ index, { number, repository } ] of batch.entries() ) {
		const repo = data[ `pr${ index }` ];
		if ( ! repo?.pullRequest ) {
			failures++;
			continue;
		}
		const pr = repo.pullRequest;
		const key = `${ repository.nameWithOwner }#${ number }`;
		if ( repo.isPrivate ) {
			skippedPrivate++;
			coverage.push( { key, url: pr.url, skipped: 'private' } );
			continue;
		}
		coverage.push( { key, url: pr.url } );
		try {
			await fetchOlderPages( repository.nameWithOwner, number, pr );
			if ( CI ) {
				await fetchCiPages( repository.nameWithOwner, number, pr );
			}
		} catch ( error ) {
			failures++;
			console.error(
				`  ${ repository.nameWithOwner }#${ number }: ${
					error.stderr?.trim() || error.message
				}`
			);
			continue;
		}
		if ( CI ) {
			for ( const check of failingChecks( pr ) ) {
				ciItems.push( {
					...check,
					pr: key,
					prUrl: pr.url,
					nameWithOwner: repository.nameWithOwner,
					state: {
						pull_request: pr.title,
						base_branch: pr.baseRefName,
						changed_files: pr.files.nodes.map( ( f ) => f.path ),
						check: {
							workflow: check.workflow,
							name: check.name,
							conclusion: check.conclusion,
							details: clip( check.details ),
						},
					},
				} );
			}
		}
		for ( const item of pendingItems( pr ) ) {
			items.push( {
				...item,
				pr: key,
				prUrl: pr.url,
				prTitle: pr.title,
			} );
		}
	}
	return items;
} );
const items = perBatch.flat();
console.error(
	`${ items.length } comments waiting on you; dropped ${ droppedBots } bot comments; skipped ${ skippedPrivate } private-repo PRs.`
);
if ( CI ) {
	console.error(
		`${ ciItems.length } failing checks across ${
			new Set( ciItems.map( ( c ) => c.pr ) ).size
		} PRs.`
	);
}

if ( DRY_RUN ) {
	const byAuthor = {};
	for ( const item of items ) {
		byAuthor[ item.author ] = ( byAuthor[ item.author ] ?? 0 ) + 1;
	}
	console.log(
		Object.entries( byAuthor )
			.sort( ( a, b ) => b[ 1 ] - a[ 1 ] )
			.map( ( [ author, count ] ) => `${ count }\t${ author }` )
			.join( '\n' )
	);
	const chars = items.reduce( ( sum, i ) => sum + JSON.stringify( i.state ).length, 0 );
	console.error(
		`Dry run: ~${ Math.round( chars / 4 ) } input tokens would be sent (~$${ (
			( chars / 4 / 1e6 ) *
			0.042
		).toFixed( 5 ) }).`
	);
	process.exit( 0 );
}

const started = Date.now();
const answered = await pool( items, async ( item ) => {
	try {
		const { answers } = await askJev( item.state );
		return { ...item, answers };
	} catch ( error ) {
		failures++;
		console.error( `  ${ item.url }: ${ error.message }` );
		return { ...item, answers: null };
	}
} );
console.error( `Jev classified ${ answered.length } comments in ${ Date.now() - started }ms.` );

// Logs expire and non-Actions checks have none; the check summary still goes to Jev.
const ciStarted = Date.now();
const ciAnswered = await pool( ciItems, async ( check ) => {
	if ( check.jobId ) {
		try {
			const { stdout } = await ghAsync(
				'api',
				'--allow-escape-sequences',
				`repos/${ check.nameWithOwner }/actions/jobs/${ check.jobId }/logs`
			);
			const { step, excerpt } = logExcerpt( stdout );
			check.state.failed_step = step;
			check.state.log_excerpt = excerpt;
		} catch {
			check.state.log_excerpt = '(log unavailable)';
		}
	}
	try {
		const { answers } = await askJev( check.state, CI_QUESTIONS );
		return { ...check, answers };
	} catch ( error ) {
		failures++;
		console.error( `  ${ check.url }: ${ error.message }` );
		return { ...check, answers: null };
	}
} );
if ( CI ) {
	console.error(
		`Jev classified ${ ciAnswered.length } failing checks in ${
			Date.now() - ciStarted
		}ms.`
	);
}

const ciAction = ( checks ) =>
	CI_ACTIONS.find( ( [ cause ] ) =>
		checks.some( ( c ) => ( c.answers?.cause.choice ?? 'real_failure' ) === cause )
	)?.[ 1 ];

const percent = ( value ) => `${ Math.round( value * 100 ) }%`;
const oneLine = ( text ) =>
	text.replace( /\s+/g, ' ' ).replace( /\|/g, '\\|' ).slice( 0, 140 );
const byNewest = ( a, b ) => b.date.localeCompare( a.date );

// A comment counts only when Jev both expects a reply and files it under a
// category that implies one; the two answers disagree on FYIs otherwise.
const ACTION_CATEGORIES = new Set( [
	'actionable_change',
	'question',
	'bot_finding',
] );
const needsAction = ( { answers: a } ) =>
	! a ||
	( a.needs_reply.noul >= 0.5 && ACTION_CATEGORIES.has( a.category.choice ) );

const actionable = answered.filter( needsAction );
const recent = actionable.filter( ( i ) => i.date >= SINCE ).sort( byNewest );
const quiet = answered.length - actionable.length;

const rows = recent.map( ( i ) => {
	const a = i.answers;
	const category = a
		? `${ a.category.choice } (${ percent( a.category.confidence ) })`
		: 'error';
	return `| ${ i.date.slice( 0, 10 ) } | [${ i.pr }](${ i.prUrl }) | ${
		i.author
	} | ${ category } | ${ a ? percent( a.blocking.noul ) : '-' } | [${ oneLine(
		i.excerpt
	) }](${ i.url }) |`;
} );

// Older PRs collapse to one row each: the question there is close or revive.
// A PR with any fresh feedback is active, so it stays out of this list.
const stalePrs = new Map();
for ( const item of actionable ) {
	const entry = stalePrs.get( item.pr ) ?? { ...item, count: 0, blocking: 0 };
	entry.count++;
	entry.blocking = Math.max( entry.blocking, item.answers?.blocking.noul ?? 0 );
	if ( item.date > entry.date ) {
		entry.date = item.date;
	}
	stalePrs.set( item.pr, entry );
}
for ( const [ pr, entry ] of stalePrs ) {
	if ( entry.date >= SINCE ) {
		stalePrs.delete( pr );
	}
}
const staleRows = [ ...stalePrs.values() ]
	.sort( byNewest )
	.map(
		( i ) =>
			`| ${ i.date.slice( 0, 10 ) } | [${ i.pr }](${ i.prUrl }) | ${ oneLine(
				i.prTitle
			) } | ${ i.count } | ${ percent( i.blocking ) } |`
	);

function ciReport() {
	const rows = ciAnswered.map( ( c ) => {
		const a = c.answers;
		const cause = a
			? `${ a.cause.choice } (${ percent( a.cause.confidence ) })`
			: 'error';
		return `| [${ c.pr }](${ c.prUrl }) | [${ oneLine( c.name ) }](${
			c.url
		}) | ${ cause } | ${ a ? percent( a.rerun_passes.noul ) : '-' } | ${ oneLine(
			c.state.failed_step ?? ''
		) } |`;
	} );
	return `
## Failing CI

${ ciAnswered.length } failing checks, one row per workflow job, at most ${ MAX_CHECKS } per PR.

| PR | Check | Cause | Rerun passes | Failed step |
| --- | --- | --- | --- | --- |
${ rows.join( '\n' ) }
`;
}

const report = `# PR comment triage - ${ TODAY }

${ recent.length } comments since ${ SINCE } likely need action, newest first. ${ quiet } more were filtered out as approvals, nits, or FYIs, and ${ droppedBots } bot comments were never sent.${
	failures ? ` ${ failures } PRs or comments failed to load or classify; see stderr.` : ''
} Classified by Jev (\`jev-latest\`).

| Date | PR | From | Category | Blocking | Comment |
| --- | --- | --- | --- | --- | --- |
${ rows.join( '\n' ) }

## Stale PRs: close or revive?

${ stalePrs.size } PRs whose unanswered feedback is all older than ${ SINCE }.

| Last feedback | PR | Title | Open items | Blocking |
| --- | --- | --- | --- | --- |
${ staleRows.join( '\n' ) }
${ CI ? ciReport() : '' }`;

if ( SUMMARY ) {
	// Counts from a partial run would look complete, so let the caller fall back.
	if ( failures ) {
		console.error( `${ failures } PRs or comments failed; not printing a summary.` );
		process.exit( 1 );
	}
	// Every loaded PR gets an entry, so a PR missing from the map or marked
	// `skipped` is one the caller must judge by its thread count instead.
	const perPr = {};
	for ( const { key, url, skipped } of coverage ) {
		perPr[ key ] = skipped
			? { url, skipped }
			: { url, pending: 0, needsAction: 0, blocking: 0, newest: null };
	}
	for ( const item of answered ) {
		const entry = perPr[ item.pr ];
		entry.pending++;
		if ( needsAction( item ) ) {
			entry.needsAction++;
			if ( ( item.answers?.blocking.noul ?? 0 ) >= 0.5 ) {
				entry.blocking++;
			}
			if ( ! entry.newest || item.date > entry.newest.date ) {
				entry.newest = {
					date: item.date,
					author: item.author,
					url: item.url,
					category: item.answers?.category.choice ?? 'error',
				};
			}
		}
	}
	const ciByPr = new Map();
	for ( const check of ciAnswered ) {
		ciByPr.set( check.pr, [ ...( ciByPr.get( check.pr ) ?? [] ), check ] );
	}
	for ( const [ pr, checks ] of ciByPr ) {
		perPr[ pr ].ci = {
			failing: checks.length,
			next: ciAction( checks ),
			checks: checks.map( ( c ) => ( {
				name: c.name,
				url: c.url,
				cause: c.answers?.cause.choice ?? 'error',
				rerunPasses: c.answers?.rerun_passes.noul ?? null,
			} ) ),
		};
	}
	console.log( JSON.stringify( perPr, null, 2 ) );
	process.exit( 0 );
}

writeFileSync( OUT, report );
writeFileSync(
	OUT.replace( /\.md$/, '.json' ),
	JSON.stringify( CI ? { comments: answered, ci: ciAnswered } : answered, null, 2 )
);
console.error( `Wrote ${ OUT }` );
