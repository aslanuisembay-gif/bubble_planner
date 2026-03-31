import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const listForUser = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      return [];
    }
    const rows = await ctx.db
      .query("tasks")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    rows.sort((a, b) => a.dueAtMs - b.dueAtMs);
    return rows;
  },
});

function demoTodayMs(): number {
  const n = new Date();
  n.setHours(0, 0, 0, 0);
  return n.getTime();
}

export const seedDemoForUser = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const existing = await ctx.db
      .query("tasks")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    if (existing.length > 0) {
      return { seeded: false as const };
    }

    const t0 = demoTodayMs();
    const ms = (h: number, m = 0) => t0 + (h * 3600 + m * 60) * 1000;
    const d1 = new Date(t0);
    d1.setDate(d1.getDate() + 1);
    const tomorrow2034 = new Date(
      d1.getFullYear(),
      d1.getMonth(),
      d1.getDate(),
      20,
      34,
    ).getTime();

    const batch = [
      {
        userId,
        categoryId: "health",
        categoryTag: "HEALTH",
        title: "BUY VITAMINS",
        dueAtMs: ms(12),
        isDone: true,
      },
      {
        userId,
        categoryId: "work",
        categoryTag: "WORK",
        title: "CONFIRM DESIGN MEETING",
        dueAtMs: ms(21, 34),
        isDone: false,
      },
      {
        userId,
        categoryId: "general",
        categoryTag: "GENERAL",
        title: "GFHGGJJKHHJ",
        dueAtMs: ms(23, 45),
        isDone: false,
      },
      {
        userId,
        categoryId: "general",
        categoryTag: "GENERAL",
        title: "TRAIN THE MARSH BEFORE HIS PLAYOFF HOCKEY GAMES",
        dueAtMs: tomorrow2034,
        isDone: false,
        recurrenceDays: ["Пн", "Ср", "Пт"],
      },
      {
        userId,
        categoryId: "shopping",
        categoryTag: "SHOPPING",
        title: "PICK UP PARCEL FROM PIATYOROCHKA",
        dueAtMs: tomorrow2034,
        isDone: false,
      },
      {
        userId,
        categoryId: "shopping",
        categoryTag: "SHOPPING",
        title: "BUY SOME GROCERIES",
        dueAtMs: ms(20, 31),
        isDone: false,
      },
    ];

    for (const row of batch) {
      await ctx.db.insert("tasks", row);
    }
    return { seeded: true as const };
  },
});

export const create = mutation({
  args: {
    categoryId: v.string(),
    categoryTag: v.string(),
    title: v.string(),
    dueAtMs: v.number(),
    isDone: v.boolean(),
    recurrenceDays: v.optional(v.array(v.string())),
    reminderAtMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const { recurrenceDays, reminderAtMs, ...rest } = args;
    const doc: {
      userId: typeof userId;
      categoryId: string;
      categoryTag: string;
      title: string;
      dueAtMs: number;
      isDone: boolean;
      recurrenceDays?: string[];
      reminderAtMs?: number;
    } = { userId, ...rest };
    if (recurrenceDays !== undefined) {
      doc.recurrenceDays = recurrenceDays;
    }
    if (reminderAtMs !== undefined) {
      doc.reminderAtMs = reminderAtMs;
    }
    return await ctx.db.insert("tasks", doc);
  },
});

export const updateFields = mutation({
  args: {
    id: v.id("tasks"),
    title: v.optional(v.string()),
    dueAtMs: v.optional(v.number()),
    isDone: v.optional(v.boolean()),
    categoryId: v.optional(v.string()),
    categoryTag: v.optional(v.string()),
    recurrenceDays: v.optional(v.array(v.string())),
    clearRecurrence: v.optional(v.boolean()),
    reminderAtMs: v.optional(v.number()),
    clearReminder: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const doc = await ctx.db.get(args.id);
    if (!doc || doc.userId !== userId) {
      throw new Error("Forbidden");
    }
    const patch: Record<string, unknown> = {};
    if (args.title !== undefined) {
      patch.title = args.title;
    }
    if (args.dueAtMs !== undefined) {
      patch.dueAtMs = args.dueAtMs;
    }
    if (args.isDone !== undefined) {
      patch.isDone = args.isDone;
    }
    if (args.categoryId !== undefined) {
      patch.categoryId = args.categoryId;
    }
    if (args.categoryTag !== undefined) {
      patch.categoryTag = args.categoryTag;
    }
    if (args.clearRecurrence) {
      patch.recurrenceDays = undefined;
    } else if (args.recurrenceDays !== undefined) {
      patch.recurrenceDays = args.recurrenceDays;
    }
    if (args.clearReminder) {
      patch.reminderAtMs = undefined;
    } else if (args.reminderAtMs !== undefined) {
      patch.reminderAtMs = args.reminderAtMs;
    }
    await ctx.db.patch(args.id, patch);
  },
});

export const remove = mutation({
  args: { id: v.id("tasks") },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const d = await ctx.db.get(args.id);
    if (!d || d.userId !== userId) {
      return;
    }
    await ctx.db.delete(args.id);
  },
});

export const removeMany = mutation({
  args: { ids: v.array(v.id("tasks")) },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    for (const id of args.ids) {
      const d = await ctx.db.get(id);
      if (d?.userId === userId) {
        await ctx.db.delete(id);
      }
    }
  },
});

export const addSyncHubDemo = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const base = demoTodayMs();
    const inserts: Array<{
      title: string;
      categoryId: string;
      categoryTag: string;
      dueAtMs: number;
    }> = [
      {
        title: "REVIEW EMAIL FROM TEAM",
        categoryId: "work",
        categoryTag: "WORK",
        dueAtMs: base + 10 * 3600 * 1000,
      },
      {
        title: "ORDER SUPPLIES FROM LIST",
        categoryId: "shopping",
        categoryTag: "SHOPPING",
        dueAtMs: base + 14 * 3600 * 1000,
      },
      {
        title: "FOLLOW UP CALENDAR INVITE",
        categoryId: "general",
        categoryTag: "GENERAL",
        dueAtMs: base + 1 * 86400 * 1000 + 9 * 3600 * 1000,
      },
      {
        title: "SCHEDULE CHECKUP FROM NOTE",
        categoryId: "health",
        categoryTag: "HEALTH",
        dueAtMs: base + 2 * 86400 * 1000 + 11 * 3600 * 1000,
      },
    ];
    for (const row of inserts) {
      await ctx.db.insert("tasks", {
        userId,
        ...row,
        isDone: false,
      });
    }
  },
});
