"""
Tutorial sample 12: cross-actor cancellation. A supervising actor holds
a CancelToken and fires SQLCancel from a timer while the Main actor
would otherwise be blocked in a long query.
"""
