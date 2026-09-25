#!/usr/bin/env node
/**
 * Triage unanswered comments on your open PRs with TypeSafe's Jev model.
 *
 * Usage:
 *   node triage.mjs [--dry-run] [--limit N] [--repo owner/name] [--out file.md]
 *                   [--since YYYY-MM-DD] [--summary]
 *
 * --summary prints per-PR counts as JSON on stdout instead of writing the
 * report, for callers that fold the counts into their own table.
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

const PR_FRAGMENT = `
fragment PendingConversation on PullRequest {
  title
  url
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

async function askJev( state ) {
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
				questions: QUESTIONS,
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
		} catch ( error ) {
			failures++;
			console.error(
				`  ${ repository.nameWithOwner }#${ number }: ${
					error.stderr?.trim() || error.message
				}`
			);
			continue;
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
`;

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
	console.log( JSON.stringify( perPr, null, 2 ) );
	process.exit( 0 );
}

writeFileSync( OUT, report );
writeFileSync( OUT.replace( /\.md$/, '.json' ), JSON.stringify( answered, null, 2 ) );
console.error( `Wrote ${ OUT }` );
