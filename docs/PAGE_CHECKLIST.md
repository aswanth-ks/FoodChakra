# Page Completion Checklist

Every UI page must pass this gate. A page is **not complete** until all relevant items are
finished. Copy this template into the page's tracking entry.

```text
PAGE: <name>
ROUTE: <path>
STITCH REF: <screen name / link>

[ ]  1. Stitch design reviewed
[ ]  2. Flutter UI implemented
[ ]  3. Responsive behavior verified
[ ]  4. Reusable widgets extracted (nothing duplicated)
[ ]  5. Navigation connected
[ ]  6. API connected
[ ]  7. Real backend data (no mocks left in the widget)
[ ]  8. MongoDB integration verified
[ ]  9. Loading state
[ ] 10. Empty state
[ ] 11. Error state (with retry)
[ ] 12. Success state
[ ] 13. Authentication / role behavior
[ ] 14. Edge cases (long text, huge lists, offline, slow network)
[ ] 15. Tested (widget test covering all four states)
[ ] 16. Visual comparison with Stitch
[ ] 17. Final approval

STATUS: NOT STARTED | IN PROGRESS | BLOCKED | COMPLETE
```

---

## Notes on the tricky items

**4 — Reusable widgets.** If a component appears on two screens, it belongs in
`lib/shared/widgets/`. Translate the Stitch design into clean Flutter architecture; do not
copy generated-UI patterns verbatim.

**7 — Real backend data.** A screen wired to hardcoded sample data is not connected. The
temporary data must be gone, not commented out.

**10 — Empty state.** An empty result is not an error. "No active donations" is a designed
state, not a blank screen.

**11 — Error state.** Use `ErrorStateView`. Never show a raw exception to a user. Always
offer a retry when the action is retryable.

**14 — Edge cases.** At minimum: a very long food name, a list with 200 items, an offline
device, and a request that takes 10 seconds.

**16 — Visual comparison.** Screenshot side by side with the Stitch design. Check layout,
spacing, typography, hierarchy, and component behavior.
