// Last-action breadcrumb: the native crash reporter has no JS context, so we
// keep the most recent action in localStorage to identify the next crash.

import { sys } from 'cc';

export function trace(tag: string): void {
    try {
        sys.localStorage.setItem('jelly_trace', `${Date.now()}|${tag}`);
    } catch {
        // Storage unavailable: tracing is best-effort.
    }
}
