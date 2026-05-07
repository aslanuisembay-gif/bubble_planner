import { authTables } from "@convex-dev/auth/server";
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * Пользователи и сессии: таблицы из `authTables` (users, authAccounts, …) в вашем
 * проекте Convex. Пароли не хранятся открытым текстом — Convex Auth держит хеш.
 * Задачи и заметки ссылаются на `userId: Id<"users">`.
 * Смотреть данные: Convex Dashboard → ваш деплой → Data.
 */
export default defineSchema({
  ...authTables,
  tasks: defineTable({
    // Widened for migration: legacy docs may store "demo" as string userId.
    userId: v.union(v.id("users"), v.string()),
    categoryId: v.string(),
    categoryTag: v.string(),
    title: v.string(),
    dueAtMs: v.number(),
    isDone: v.boolean(),
    recurrenceDays: v.optional(v.array(v.string())),
    reminderAtMs: v.optional(v.number()),
    /// Minutes before due: 5, 30, 60 — several can be set at once.
    reminderOffsets: v.optional(v.array(v.number())),
  }).index("by_user", ["userId"]),
  notes: defineTable({
    // Widened for migration: legacy docs may store string userId.
    userId: v.union(v.id("users"), v.string()),
    title: v.optional(v.string()),
    text: v.string(),
    folder: v.string(),
    tags: v.array(v.string()),
    imagesBase64: v.array(v.string()),
    createdAtMs: v.number(),
    updatedAtMs: v.number(),
  }).index("by_user", ["userId"]),
  userProfiles: defineTable({
    userId: v.id("users"),
    displayName: v.string(),
    avatarBase64: v.optional(v.string()),
    updatedAtMs: v.number(),
  }).index("by_user", ["userId"]),
  feedback: defineTable({
    // Signed-in cloud users store Id<"users">, fallback (demo/guest) stores string marker.
    userId: v.union(v.id("users"), v.string()),
    contactType: v.union(v.literal("email"), v.literal("phone")),
    contact: v.string(),
    message: v.string(),
    languageCode: v.string(),
    createdAtMs: v.number(),
  })
    .index("by_created", ["createdAtMs"])
    .index("by_user", ["userId"]),
});
