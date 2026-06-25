# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Over-Mocking Detection

**The #1 cause of "tests pass but runtime fails":** mocking internal dependencies hides real integration bugs.

**Checklist — for every mock in your test, ask:**

1. Is this a system boundary? (external API, DB, time, network) → OK
2. Is this code I wrote in this codebase? → DON'T MOCK
3. Would this mock hide a bug? (e.g., wrong interface shape, missing validation) → DON'T MOCK
4. Am I mocking because it's hard to set up, not because it's external? → FIX THE SETUP, DON'T MOCK

**Symptom of over-mocking:**
- Test passes but the real integration fails
- Test only verifies that method A called method B, not that the output is correct
- Removing the mock would only require a test DB fixture, not an actual API

**Fix over-mocked tests:**
1. Replace the mock with a real instance or test fixture
2. If setup is complex, extract a factory function — don't mock
3. If the dependency is slow, use a test double that exercises the real code path

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
