# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.addItem({ id: "prod-1", qty: 2, price: 10 });
  const result = await checkout(cart, createMockPayment());
  expect(result.status).toBe("confirmed");
  expect(result.total).toBe(20);
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details — mocks internal collaborator
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

## Required Test Categories

Every REQ must cover at least:

### 1. Happy Path
The expected flow with valid input. One test per REQ is the minimum.

### 2. Negative Cases
At least ONE per REQ:
- Invalid input → error response
- Missing required field → validation error
- Wrong permission → access denied

### 3. Boundary Conditions
When the logic has thresholds, ranges, or limits:
- Empty collection, single item, max items
- Zero, negative, overflow
- Min/max string length

### 4. Error Handling
When the code handles external failures:
- Network timeout → retry/fallback
- DB connection lost → error message
- Rate limited → backoff

## Test Quality Self-Check

After writing each test, verify:

- [ ] If I remove the implementation, does this test FAIL? (not always-pass)
- [ ] If I change an internal function name, does this test still PASS? (not impl-coupled)
- [ ] Does the test assert the OUTPUT, not the CALLS? (not mock-verification)
- [ ] Does the test name describe what a user/caller cares about? (behavior, not mechanics)
- [ ] Does the test use real collaborators, not mocks? (except system boundaries)
