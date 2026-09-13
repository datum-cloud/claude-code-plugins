---
name: clear-writing
description: Rules for prose a busy reader understands on the first pass, for docs, READMEs, error messages, issues, comments, and any other text written for a human. Use whenever writing more than a sentence of prose. The pr-op-gate hook refuses the phrases in the enforced table.
---

# Clear Writing

Unclear writing is a failed transfer of information. The reader gives up,
misreads, or writes back to ask. Every rule here removes one way that
transfer breaks.

One test governs all of it: **could a smart person outside your team read
this once and act on it correctly?**

This skill is the prose basis for every Datum repository. `pr-conventions`
adds the countable bar for GitHub bodies and `commit-conventions` owns commit
messages. Neither restates what is here.

Adapted from the European Economic and Social Committee's
[*Clear Writing*](https://www.eesc.europa.eu/sites/default/files/2024-04/qe-05-24-273-en-n.pdf)
(2024). The technical section is ours.

## Answer the seven questions

Before writing, know what the reader walks away with: **what** is happening,
**who** does it and to whom, **when**, **where**, **how**, **why**, and **how
much**. Vague text is usually text that skipped three of these.

> ❌ At the appropriate stage, the necessary steps will be taken to tackle the
> problems arising in several regions.
>
> ✅ Over the next six months, the central bank will lend EUR 10 billion to
> Ireland, Spain, and Portugal to help them manage their debt.

The second is longer. It is also the only one that says anything.

A hedged non-commitment ("we will look into optimizing the process where
appropriate") answers none of the seven. When you do not know the *when* or
the *how much*, say so outright. "We don't have a date yet" beats
abstraction dressed as a plan.

## Verbs carry the meaning

Turning a verb into a noun and propping it up with a weak verb (*make,
provide, undertake, carry out, achieve*) is the fastest way to make a
sentence dense and lifeless. Undo it.

Scan for stacks of **-tion, -ment, -ance, -ence, -ity, -ing of**. Find the
real action and ask whether it is currently a noun.

| Noun form | Verb |
|---|---|
| conduct an analysis of | analyze |
| provide clarification on | clarify |
| make an assessment of | assess |
| the implementation of X by Y | Y implements X |

> ❌ There is a need for an intensification of efforts aimed at the prevention
> of the pollution of the coastlines of Europe through the accidental spillage
> of oil. *(27 words)*
>
> ✅ We must do more to protect Europe's coasts from oil spills. *(11 words)*

Passive voice is legitimate when the actor is unknown, irrelevant, or when
the object is the topic: "the server was compromised on Tuesday". Use it
deliberately. "Mistakes were made" exists to remove the actor. Do not do that
by accident.

## Order the sentence

Name the actor early. Put events in the order they happen. Put the
important information at the end, where it lands hardest.

> ❌ Its decision on allocation of assistance will be taken subsequent to
> receipt of all project applications at the Award Committee's meeting.
>
> ✅ Once all applications are in, the Award Committee will meet and decide
> how much each project receives.

A modifier attaches to whatever is nearest. If that is not what you meant,
the reader gets a different sentence than the one you wrote.

> ❓ Rules were adopted on packaging toys as recommended by the Consumer
> Council. *(Did the Council recommend the rules, or the packaging?)*
>
> ✅ As the Consumer Council recommended, new rules were adopted on toy
> packaging.

**"Which" is the most common offender.** A "which" clause reaches back to an
ambiguous antecedent more often than writers notice. When it does, start a
new sentence and name the thing again.

## Commas change meaning

A comma before a relative clause makes it *non-restrictive*, extra
information about all of the thing. No comma makes it *restrictive*, and
narrows which ones you mean.

> **With comma:** children, who are particularly vulnerable to pollutants,
> spend most of their day there. *(All children are vulnerable.)*
>
> **Without comma:** children who are particularly vulnerable to pollutants
> spend most of their day there. *(Only some children are vulnerable.)*

Read every relative clause, decide which reading you want, then punctuate
for it.

## Be concrete

Abstraction is where meaning goes to die. Name the actual thing, the actual
person, the actual number.

> ❌ It is a matter of necessity that citizens be aware of the division of
> competences among institutions.
>
> ✅ People need to know who does what.

**Numbers beat adjectives.** "Performance improved substantially" tells the
reader nothing. "Load time dropped from 4.1s to 0.9s" tells them everything.

## Titles and headings

Every rule above applies to a title, and applies harder. The title is the one
line everyone reads, it is what the reader sees in a list of forty others, and
it is the only part with no room to recover from a bad first sentence.

**Name the subject.** Use the word a reader outside the team would use for the
thing, and use it in the title, not in the third paragraph. A phrase that
stands in for the subject reads as a riddle, and the reader who cannot solve
it concludes they were supposed to already know.

> ❌ A dependency we cannot carry can land with nothing to stop it
>
> ✅ No CI check blocks a copyleft dependency from landing

The first title never says *license*, which is what it is about. It asks the
reader to work out that "cannot carry" means a license incompatible with the
repository's own.

**One negation, at most.** Each one is a step the reader takes before reaching
the meaning, and two of them turn a title into arithmetic. Say what is broken,
or what changes, rather than what is absent.

> ❌ Nothing prevents a zone from having no owner
>
> ✅ A zone can lose its owner and keep serving

**The title stands alone.** A reader who never opens the body should still
know what the post is about. A title that only makes sense once you have read
the first paragraph is a title that failed.

**Say the outcome, not the mechanism.** `pr-conventions` carries the format:
the conventional prefix, imperative mood, and the 72-character limit.

## Negations the title gate counts

`pr-op-gate` counts these words in a title and refuses a title carrying more
than one. Contractions ending in `n't` count too; the gate matches those by
shape rather than from this table. Edit this table to change what the gate
counts.

| Word | Counts as |
|---|---|
| no / not / nothing / none / never / nobody / neither / nor / without / cannot / unable | one negation |

A count of one is normal and often the clearest thing to write. The cap exists
to catch the title that makes the reader resolve two before the subject
arrives.

## Abbreviations and Latin

Spell out an abbreviation at first use with the short form in brackets, then
use the short form. Never stack three unfamiliar abbreviations in one
sentence.

Latin sounds formal and excludes readers for no gain. The enforced table
below carries the replacements. A legal term of art may need to stay, so
explain it: not "has the force of res judicata" but "is final and cannot be
appealed".

## Choose the right word

Precision failures that survive spellcheck:

| Pair | Distinction |
|---|---|
| **exclude** / **exempt** | excluded means *not allowed to*; exempt means *not required to* |
| **ensure** / **insure** / **assure** | make certain / buy financial cover / tell someone confidently |
| **affect** / **effect** | to influence (verb) / a result (noun) |
| **comprise** / **compose** | the whole comprises the parts; the parts compose the whole |
| **fewer** / **less** | fewer for countable things; less for quantities |
| **imply** / **infer** | the speaker implies; the listener infers |
| **principle** / **principal** | a rule / main, or the person in charge |
| **continual** / **continuous** | repeatedly / without interruption |

Words that shift meaning between languages mislead international readers.
Use the unambiguous choice:

- **eventually** means *in the end, certainly*, not *possibly*. Say "may
  close", not "will eventually close".
- **actual** means *real*, not *current*. Say "current address".
- **delay** means *lateness*, not *a period allowed*. Say "payment is due
  within three months".
- **foresee** means *predict*, not *provide for*. Say "the move is scheduled
  for December".
- **control** means *command* or *restrain*. Often the intended word is
  *check, inspect, verify, monitor*.
- **respect** applies to people and values. A deadline or rule is *met*,
  *observed*, or *followed*.
- **elaborate** means *expand on*, not *draft*. "Consultants designed the
  website", not "elaborated" it.

## Phrases the gate refuses

`pr-op-gate` reads this table and refuses any GitHub post, whether an opening
post, a comment, a review, or release notes, that uses a phrase in the first
column outside code formatting or a quotation. Each row lists
the forms it matches, separated by `/`. Edit this table to change what the
gate enforces.

| Phrase | Write instead |
|---|---|
| with reference to / with regard to / in relation to / on the subject of | about |
| due to the fact that / owing to the fact that / in view of the fact that / for the reason that / the reason is because | because |
| in the event that / on condition that | if |
| it goes without saying | nothing, or "clearly" |
| in comparison to / by comparison with | than |
| at this point in time | now |
| in order to | to |
| a number of | the number, or "some" |
| has the ability to / is in a position to | can |
| take into consideration | consider |
| make a decision | decide |
| provide assistance to | help |
| contribute to improving | help improve |
| facilitate / facilitates / facilitated / facilitating | help, or the specific verb |
| utilize / utilizes / utilized / utilizing / utilization | use |
| commence / commences / commenced | start |
| prior to | before |
| subsequent to | after |
| in the vicinity of | near |
| inter alia | including, or among other things |
| e.g. | for example |
| i.e. | that is, or meaning |
| prima facie | at first sight |
| de facto | in effect, or actual |
| ex ante | in advance |
| ex post | afterwards |
| ipso facto | therefore |
| in toto | as a whole |
| mutatis mutandis | with the necessary changes |
| per se | in itself |
| vis-à-vis / vis-a-vis | compared with, or regarding |
| circa | about |
| blue-sky thinking | new ideas |
| deliverables | results, or outputs |
| in the loop | informed |
| human capital | people, staff, or skills |
| modalities | arrangements, or procedures |
| operationalize / operationalise | put into practice, or start doing |
| circle back | follow up |
| align on | agree on |
| leverage / leverages / leveraged / leveraging | use, or name the mechanism |
| synergies | working together, or shared expertise |
| going forward | from now on, or nothing |
| in a timely manner | the actual deadline |
| stakeholders | name them |

Corporate euphemism is jargon with a motive. "Rightsizing", "letting people
go", "sunsetting the product". If the plain word feels harsh, that is
information about the thing, not a reason to hide it.

## Words to weigh

These are not refused, because each has honest uses. Ask whether the plain
alternative says more.

| Word | Ask |
|---|---|
| significant / substantial | Do you have the number? Give it. |
| bandwidth | Network capacity, or a person's time? Say which. |
| terminate / initiate | A pod terminates and a handshake initiates. A meeting ends and a rollout starts. |
| provided that | A precondition, or plain "if"? |
| terms of art | Precise among specialists. For a mixed audience, define at first use, then use freely. For outsiders, replace. |

## Technical writing

The rules above apply, plus these.

**Lead with what it is and what problem it solves, in one sentence.** A
reader deciding whether to keep reading needs that before the badges, the
philosophy, or the history.

> ❌ In today's rapidly evolving microservice landscape, observability has
> become a critical concern for engineering organizations of all sizes…
>
> ✅ `tracekit` collects distributed traces from Go services and ships them to
> any OTLP endpoint. Zero config for the common case.

**Write instructions as imperatives addressed to the reader.** "Set `API_KEY`
before running the server", not "the user should then be able to configure
the environment variables as needed".

**Say what happens, not what should happen.** "The build should complete in
about a minute" is a hedge. Either it does, or say what to do when it does
not.

**Every code block states its purpose and its result.** Show the command,
then the expected output. A reader who cannot tell whether their result is
correct is stuck.

**Document the failure modes.** The reader is usually reading *because*
something failed. State the common errors and what causes them.

**A comment explains what the code does not say.** Restating the line
beneath is noise. Recording *why*, the constraint, the bug worked around,
the option rejected, is what survives.

**Prefer the noun to the pronoun.** "It", "this", and "that" often have three
candidate antecedents in the previous sentence. Repeat the noun. Repetition
is not a flaw in technical prose. Ambiguity is.

**An error message states what failed, why, and what to do next.** It is
documentation delivered at the worst possible moment.

> ❌ Error: invalid configuration
>
> ✅ Error: `timeout` must be a positive integer (got "-1") in config.yaml
> line 12.

**Reference docs state the contract, not the intention.** What it takes,
what it returns, what it raises, what it mutates, whether it is safe to call
concurrently. "Handles user authentication" is an aspiration. "Returns a
session token valid for 24 hours, or raises `AuthError` if the credentials
are rejected" is a contract.

## Before you send it

- Read it once from the reader's position. What do they know? What will
  they do next?
- Look for any sentence over 25 words and try splitting it.
- Search for **-tion**, **-ment**, **is/are/was/were + past participle**,
  and **of the**. Each hit is a candidate for a verb.
- Delete the first sentence. If it was throat-clearing, you will never miss
  it.
- Cut 10% of the words. It is almost always possible.
- Run a spellcheck.

> *"Those who write clearly have readers; those who write obscurely have
> commentators."* (attributed to Albert Camus)
