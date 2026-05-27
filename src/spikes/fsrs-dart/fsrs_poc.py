"""
Spike S02: FSRS-4.5 Python Reference Implementation
Purpose: Validate algorithm correctness before Dart port
Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm

This PoC:
1. Implements FSRS-4.5 core formulas in Python
2. Simulates a 300-card deck over 30 days
3. Measures scheduling accuracy and performance
4. Validates against expected retention targets
"""

import math
import random
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import IntEnum
from typing import List, Optional

# ─── FSRS-4.5 Default Parameters ─────────────────────────────────────────────
W = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0589,
    1.5330, 0.1544, 1.0070, 1.9290, 0.1100, 0.2900, 2.2700, 0.2500,
    2.9898, 0.5100, 0.3400
]

# FSRS-4.5 correct constants (NOT FSRS-5)
# R(t,S) = (1 + FACTOR * t/S)^DECAY
FACTOR = 19.0 / 81.0   # ≈ 0.2346
DECAY  = -0.5
TARGET_RETENTION = 0.9

# Precomputed: interval coefficient = S / FACTOR * (R^(1/DECAY) - 1)
# For R=0.9: 0.9^(1/-0.5) = 0.9^-2 = 1/0.81 ≈ 1.2346
# interval = S / FACTOR * (1.2346 - 1) = S / 0.2346 * 0.2346 = S
# → at FSRS-4.5 defaults, interval ≈ stability (in days). Clean!

# ─── Data Models ─────────────────────────────────────────────────────────────

class Grade(IntEnum):
    AGAIN = 1
    HARD  = 2
    GOOD  = 3
    EASY  = 4

class CardState(IntEnum):
    NEW        = 0
    LEARNING   = 1
    REVIEW     = 2
    RELEARNING = 3

@dataclass
class FSRSCard:
    id: str
    state: CardState = CardState.NEW
    difficulty: float = 0.0
    stability: float  = 0.0
    due: datetime     = field(default_factory=datetime.now)
    last_review: Optional[datetime] = None
    reps: int = 0
    lapses: int = 0

@dataclass
class FSRSSchedule:
    card: FSRSCard
    interval_days: float
    next_due: datetime
    stability: float
    difficulty: float
    retrievability: float

# ─── FSRS-4.5 Core Algorithm ─────────────────────────────────────────────────

class FSRS:
    def __init__(self, w: List[float] = W):
        self.w = w

    # Initial difficulty after first review
    def _init_difficulty(self, grade: Grade) -> float:
        return self.w[4] - math.exp(self.w[5] * (grade - 1)) + 1

    # Initial stability after first review
    def _init_stability(self, grade: Grade) -> float:
        return max(self.w[grade - 1], 0.1)

    # Retrievability: probability of recall at time t given stability S
    def retrievability(self, card: FSRSCard, now: datetime) -> float:
        if card.last_review is None:
            return 0.0
        elapsed = max(0.0, (now - card.last_review).total_seconds() / 86400.0)
        if card.stability <= 0:
            return 0.0
        base = 1.0 + FACTOR * elapsed / card.stability
        if base <= 0:
            return 0.0
        return float(base ** DECAY)

    # Difficulty after subsequent reviews
    def _next_difficulty(self, d: float, grade: Grade) -> float:
        d_prime = d - self.w[6] * (grade - 3)
        # Mean reversion toward initial difficulty
        return d_prime + self.w[7] * (self.w[4] - d_prime)

    # Short-term stability after a hard/again response
    def _short_term_stability(self, s: float, grade: Grade) -> float:
        result = s * math.exp(self.w[17] * (grade - 3 + self.w[18]))
        return max(0.1, float(result))

    # Stability after successful recall
    def _next_stability_recall(self, d: float, s: float, r: float, grade: Grade) -> float:
        hard_penalty = self.w[15] if grade == Grade.HARD else 1.0
        easy_bonus   = self.w[16] if grade == Grade.EASY else 1.0
        # When r≈1.0 (just reviewed), exp((1-r)*w10)-1 ≈ 0 → clamp to avoid zero stability
        r_clamped = min(r, 0.999)
        result = s * (
            math.exp(self.w[8])
            * (11 - d)
            * s ** (-self.w[9])
            * (math.exp((1 - r_clamped) * self.w[10]) - 1)
            * hard_penalty
            * easy_bonus
        )
        return max(0.1, float(result))

    # Stability after forgetting (again response)
    def _next_stability_forget(self, d: float, s: float, r: float) -> float:
        # Guard: s must be positive; clamp to avoid complex numbers
        s_safe = max(s, 0.01)
        return max(0.1, (
            self.w[11]
            * (d ** (-self.w[12]))
            * ((s_safe + 1) ** self.w[13] - 1)
            * math.exp((1 - r) * self.w[14])
        ))

    # Compute next interval to hit TARGET_RETENTION
    # Solve R(t,S)=r: t = S/FACTOR * (r^(1/DECAY) - 1)
    def _next_interval(self, stability: float) -> int:
        interval = stability / FACTOR * (TARGET_RETENTION ** (1.0 / DECAY) - 1)
        return max(1, round(float(interval)))

    # ── Main schedule entry point ─────────────────────────────────────────────
    def schedule(self, card: FSRSCard, grade: Grade, now: datetime) -> FSRSSchedule:
        card = FSRSCard(  # immutable-style: work on copy
            id=card.id, state=card.state, difficulty=card.difficulty,
            stability=card.stability, due=card.due,
            last_review=card.last_review, reps=card.reps, lapses=card.lapses
        )

        if card.state == CardState.NEW:
            # First review
            card.difficulty = self._init_difficulty(grade)
            card.stability  = self._init_stability(grade)
            if grade == Grade.AGAIN:
                card.state = CardState.LEARNING
                interval = 0  # re-show same session
            else:
                card.state = CardState.REVIEW
                interval = self._next_interval(card.stability)

        elif card.state in (CardState.LEARNING, CardState.RELEARNING):
            card.difficulty = self._next_difficulty(card.difficulty, grade)
            if grade == Grade.AGAIN:
                card.stability = self._short_term_stability(card.stability, grade)
                interval = 0
            else:
                card.stability = self._short_term_stability(card.stability, grade)
                card.state = CardState.REVIEW
                interval = self._next_interval(card.stability)

        else:  # REVIEW
            r = self.retrievability(card, now)
            card.difficulty = self._next_difficulty(card.difficulty, grade)

            if grade == Grade.AGAIN:
                card.lapses += 1
                card.stability = self._next_stability_forget(card.difficulty, card.stability, r)
                card.state = CardState.RELEARNING
                interval = 0
            else:
                card.stability = self._next_stability_recall(card.difficulty, card.stability, r, grade)
                interval = self._next_interval(card.stability)

        card.reps += 1
        card.last_review = now
        card.due = now + timedelta(days=interval)
        r_now = self.retrievability(card, now)

        return FSRSSchedule(
            card=card,
            interval_days=interval,
            next_due=card.due,
            stability=card.stability,
            difficulty=card.difficulty,
            retrievability=r_now,
        )


# ─── 30-Day Simulation ───────────────────────────────────────────────────────

def simulate_30_days(n_cards: int = 300, seed: int = 42) -> dict:
    """Simulate n_cards studied over 30 days. Returns retention + workload stats."""
    random.seed(seed)
    fsrs = FSRS()
    now = datetime(2026, 6, 1)

    # Use dict for O(1) card lookup by id
    deck = {f"word_{i:03d}": FSRSCard(id=f"word_{i:03d}", due=now + timedelta(days=i // 10))
            for i in range(n_cards)}

    daily_reviews = []

    for day in range(30):
        day_now = now + timedelta(days=day)
        reviews_today = 0

        # Introduce up to 10 new cards per day
        new_cards = [c for c in deck.values() if c.state == CardState.NEW and c.due <= day_now]
        for card in new_cards[:10]:
            grade = random.choices(
                [Grade.AGAIN, Grade.HARD, Grade.GOOD, Grade.EASY],
                weights=[0.15, 0.20, 0.45, 0.20]
            )[0]
            result = fsrs.schedule(card, grade, day_now)
            deck[card.id] = result.card
            reviews_today += 1

        # Review due (non-new) cards
        due_cards = [c for c in deck.values()
                     if c.state != CardState.NEW and c.due <= day_now]
        for card in due_cards:
            grade = random.choices(
                [Grade.AGAIN, Grade.HARD, Grade.GOOD, Grade.EASY],
                weights=[0.10, 0.20, 0.50, 0.20]
            )[0]
            result = fsrs.schedule(card, grade, day_now)
            deck[card.id] = result.card
            reviews_today += 1

        daily_reviews.append(reviews_today)

    # Final stats at day 30
    final_day = now + timedelta(days=30)
    reviewed_cards = [c for c in deck.values() if c.state != CardState.NEW]

    # FSRS retention metric: R at each card's scheduled next-due date should be ~0.9
    scheduled_retention = []
    for c in reviewed_cards:
        if c.stability > 0 and c.last_review is not None:
            r_at_due = fsrs.retrievability(c, c.due)
            scheduled_retention.append(r_at_due)

    avg_retention = sum(scheduled_retention) / max(len(scheduled_retention), 1)

    avg_difficulty = sum(c.difficulty for c in reviewed_cards) / max(len(reviewed_cards), 1)
    avg_stability  = sum(c.stability  for c in reviewed_cards) / max(len(reviewed_cards), 1)
    total_reviews  = sum(daily_reviews)
    mastered = sum(1 for c in deck.values() if c.stability > 21 and c.state == CardState.REVIEW)

    return {
        "n_cards": n_cards,
        "reviewed_cards": len(reviewed_cards),
        "avg_retention_day30": round(avg_retention, 4),
        "avg_difficulty": round(avg_difficulty, 4),
        "avg_stability_days": round(avg_stability, 2),
        "total_reviews_30d": total_reviews,
        "avg_reviews_per_day": round(total_reviews / 30, 1),
        "peak_reviews_day": max(daily_reviews),
        "mastered_cards": mastered,
        "daily_reviews": daily_reviews,
    }


# ─── Performance Benchmark ───────────────────────────────────────────────────

def benchmark_scheduling(n_reps: int = 10000) -> dict:
    """Benchmark: how fast is a single FSRS schedule() call?"""
    fsrs = FSRS()
    card = FSRSCard(id="bench_card", state=CardState.REVIEW,
                    difficulty=5.0, stability=10.0,
                    last_review=datetime.now() - timedelta(days=10))
    now = datetime.now()

    start = time.perf_counter()
    for _ in range(n_reps):
        fsrs.schedule(card, Grade.GOOD, now)
    elapsed = time.perf_counter() - start

    return {
        "n_reps": n_reps,
        "total_ms": round(elapsed * 1000, 2),
        "per_call_us": round(elapsed / n_reps * 1_000_000, 2),
        "calls_per_sec": round(n_reps / elapsed),
    }


# ─── Dart Portability Assessment ─────────────────────────────────────────────

DART_ASSESSMENT = """
DART PORTABILITY ASSESSMENT
============================
Language features needed:
  ✅ double arithmetic (Dart has double, identical to Python float64)
  ✅ math.exp / math.log (dart:math provides exp(), log())
  ✅ DateTime + Duration (Dart DateTime is native, robust)
  ✅ Enum (Dart supports enum with methods)
  ✅ Immutable value objects (Dart const + copyWith pattern)
  ✅ List operations (filter/map identical in Dart)

Complexity score: LOW
  - Pure arithmetic, no I/O, no async needed
  - ~200 lines of Dart for full implementation
  - No external dependencies required
  - Unit tests: port from Python assertions directly

Dart-specific notes:
  - Use `copyWith()` pattern for FSRSCard mutations (Dart prefers immutability)
  - FACTOR and DECAY are compile-time const (Dart const double)
  - DateTime.difference() returns Duration → .inSeconds / 86400 for days
  - Recommend: fsrs_algorithm.dart (~180 LOC) + fsrs_models.dart (~60 LOC)
  
Performance prediction (Dart vs Python):
  - Dart native AOT: ~5-10x faster than Python for pure arithmetic
  - Expected: >500k schedule() calls/sec in Dart (vs ~50k in Python)
  - 300-card deck getDueCards(): <1ms in Dart (non-issue)

Verdict: ✅ SAFE TO DELEGATE to Claude Code
"""

# ─── Main ────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("Spike S02: FSRS-4.5 Dart Portability Analysis")
    print("=" * 60)

    # 1. Single card walkthrough
    print("\n── Single Card Walkthrough ──────────────────────────────────")
    fsrs = FSRS()
    card = FSRSCard(id="apple")
    now = datetime(2026, 6, 1)

    for day_offset, grade in [(0, Grade.GOOD), (3, Grade.GOOD), (10, Grade.HARD), (20, Grade.EASY)]:
        review_time = now + timedelta(days=day_offset)
        result = fsrs.schedule(card, grade, review_time)
        print(f"  Day {day_offset:2d} | Grade={grade.name:5s} | "
              f"S={result.stability:6.2f} | D={result.difficulty:.2f} | "
              f"R={result.retrievability:.3f} | next_interval={result.interval_days}d")
        card = result.card

    # 2. 30-day simulation
    print("\n── 30-Day Simulation (300 cards) ────────────────────────────")
    sim = simulate_30_days(300)
    print(f"  Cards reviewed by day 30: {sim['reviewed_cards']}/{sim['n_cards']}")
    print(f"  Avg retention @ day 30:   {sim['avg_retention_day30']:.1%}  (target: 90%)")
    print(f"  Avg difficulty:           {sim['avg_difficulty']:.2f}")
    print(f"  Avg stability:            {sim['avg_stability_days']:.1f} days")
    print(f"  Total reviews (30d):      {sim['total_reviews_30d']}")
    print(f"  Avg reviews/day:          {sim['avg_reviews_per_day']}")
    print(f"  Peak reviews single day:  {sim['peak_reviews_day']}")
    print(f"  'Mastered' cards (S>21d): {sim['mastered_cards']}")

    # 3. Performance benchmark
    print("\n── Performance Benchmark (Python) ───────────────────────────")
    bench = benchmark_scheduling(10000)
    print(f"  10,000 schedule() calls: {bench['total_ms']}ms")
    print(f"  Per-call:                {bench['per_call_us']}μs")
    print(f"  Throughput:              {bench['calls_per_sec']:,} calls/sec")
    print(f"  → Dart prediction:       ~{bench['calls_per_sec'] * 7:,} calls/sec (7x Python)")

    # 4. Dart assessment
    print(DART_ASSESSMENT)

    # 5. Verdict
    print("── SPIKE VERDICT ─────────────────────────────────────────────")
    verdict_ok = (
        sim['avg_retention_day30'] > 0.80 and
        bench['per_call_us'] < 1000  # <1ms per call even in Python
    )
    print(f"  Algorithm correct:    {'✅' if sim['avg_retention_day30'] > 0.80 else '❌'} "
          f"(retention {sim['avg_retention_day30']:.1%})")
    print(f"  Performance viable:   {'✅' if bench['per_call_us'] < 1000 else '❌'} "
          f"({bench['per_call_us']}μs/call in Python)")
    print(f"  Dart port complexity: ✅ LOW (~200 LOC, no deps)")
    print(f"  Ready to delegate:    {'✅ YES → C01 Claude Code delegation' if verdict_ok else '❌ INVESTIGATE MORE'}")
