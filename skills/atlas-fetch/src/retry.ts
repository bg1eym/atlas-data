/**
 * Retry helper for transient fetch failures (5xx, 429, timeout).
 */

const RETRY_MAX = 2;
const RETRY_DELAY_MS = 1000;

function isRetryable(err: unknown): boolean {
  const msg = String(err);
  return (
    msg.includes("429") ||
    msg.includes("500") ||
    msg.includes("502") ||
    msg.includes("503") ||
    msg.includes("rate") ||
    msg.includes("timeout") ||
    msg.includes("ETIMEDOUT") ||
    msg.includes("ECONNRESET")
  );
}

export async function withRetry<T>(fn: () => Promise<T>, sourceId: string): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= RETRY_MAX; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (attempt < RETRY_MAX && isRetryable(err)) {
        const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
        if (typeof window === "undefined") {
          console.log(`[fetch] retry ${attempt + 1}/${RETRY_MAX} for ${sourceId} in ${delay}ms`);
        }
        await new Promise((r) => setTimeout(r, delay));
      } else {
        throw err;
      }
    }
  }
  throw lastErr;
}
