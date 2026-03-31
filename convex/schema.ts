import { authTables } from "@convex-dev/auth/server";
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  ...authTables,
  tasks: defineTable({
    userId: v.id("users"),
    categoryId: v.string(),
    categoryTag: v.string(),
    title: v.string(),
    dueAtMs: v.number(),
    isDone: v.boolean(),
    recurrenceDays: v.optional(v.array(v.string())),
    reminderAtMs: v.optional(v.number()),
  }).index("by_user", ["userId"]),
});
