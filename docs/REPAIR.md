We are working on repairing the updated Watchdom (advanced), in aligning it with BashFX the developer lost features of the original and broke some of the code. The UX has drifted as well. We need the UX and features corrected in advanced, as it is in the original (working). Review the MD files for full context. PRD -> BASHFX -> PLAN -> README -> SESSION -> WORKING -> ADVANCED

the other problem is that it does not adhere correctly to BashFX like you said, but the standard function interface for example is not implemented correctly, and main is overloaded with too much functionality, we need functions broken up in a smarter way and not massive do-everything functions.

We dont need to add the watchdom <domain> command back, its fine to have watchdom watch <domain> <opts>, thats not an issue, in fact using the command structure is more idiomatic of BashFX.

First examine the featureset in the working watchdom, note the featurset in advacned. Analyze which features are complete vs new, then determine which features in advanced are syntaticaly broken, edge cases not accounted for, missing values, etc.; once the functionality is accounted for and corrected. We should say yes advanced is working, now lets fix the UX; my favorite feature if the polling UX from the original, it keeps an animated counter going in a colored string that makes it clear and distinct from other messages (although its missing its prefix glyph), and keeps a trailing history of the watchers that completed in grey. This is visually pleasing and needs to be restored in advanced. 

The live poller signature is also not clear, it should look more like.

Live > NEXT_POLL | TARGET TIME DISTANCE | ACTIVITY | LOCAL TIME | LOCAL DATE 

NEXT_POLL -> 1:30:27 (the countdown timer shows the most significant time factor, if seconds for example only show seconds)
          -> 30:27
          -> 27s
          -> 3d 1:30:27 (countdown with days)


The Phase approach gently shifts the color of the animated poller, depending on the state, as it gets hot it gets more red, as it gets cool it gets more blue. When the target poll time is reached it prints a clear message that marker has passed. If the poller reaches a success condition it celebrates with a fun UX. 

(Domain Lifecycle Status) One aspect that is missing from the poller is not just looking for a string match, but reporting on what the status of the domain is first, like registered, pendingDelete, not found, etc; this should be reported in the trailing grey poller outcomes once the poller completes, instead of just reprinting what the poller was. The poller outcome should account for all stages of a domain life-cycle. If the actual domain status is not reported, its a waste of the query. Its not useful to see just the fact that the last poller was x seconds. The final output should be more like the time it ended, the domain it was checking, the status of the domain, the service it checked, etc

Done > Poll completed at TIME_DONE | DOMAIN.COM PENDING-DELETE | VERISIGN | POLL_LENGTH | PASS/FAIL/WATCH

(QUERY COMMAND) we need a query command for a direct request that isnt based on a timer, I think we have this but its buried into using another feature -- query command would be a direct interface. 

Fundamentally we do not want to change the direction that advanced was going, just that it has clear defects and implementation gaps.

In any case the updated UX should be more purposefuly in what it does and does not show.
