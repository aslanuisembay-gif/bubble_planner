import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const listForUser = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) return [];
    const rows = await ctx.db
      .query("notes")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    rows.sort((a, b) => b.updatedAtMs - a.updatedAtMs);
    return rows;
  },
});

export const create = mutation({
  args: {
    title: v.optional(v.string()),
    text: v.string(),
    folder: v.string(),
    tags: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) throw new Error("Unauthenticated");
    const now = Date.now();
    return await ctx.db.insert("notes", {
      userId,
      title: args.title ?? "",
      text: args.text,
      folder: args.folder,
      tags: args.tags,
      imagesBase64: [],
      createdAtMs: now,
      updatedAtMs: now,
    });
  },
});

export const updateFields = mutation({
  args: {
    id: v.id("notes"),
    title: v.optional(v.string()),
    text: v.optional(v.string()),
    folder: v.optional(v.string()),
    tags: v.optional(v.array(v.string())),
    imagesBase64: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) throw new Error("Unauthenticated");
    const doc = await ctx.db.get(args.id);
    if (!doc || doc.userId !== userId) throw new Error("Forbidden");

    const patch: Record<string, unknown> = { updatedAtMs: Date.now() };
    if (args.title !== undefined) patch.title = args.title;
    if (args.text !== undefined) patch.text = args.text;
    if (args.folder !== undefined) patch.folder = args.folder;
    if (args.tags !== undefined) patch.tags = args.tags;
    if (args.imagesBase64 !== undefined) patch.imagesBase64 = args.imagesBase64;
    await ctx.db.patch(args.id, patch);
  },
});

export const addImage = mutation({
  args: {
    id: v.id("notes"),
    imageBase64: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) throw new Error("Unauthenticated");
    const doc = await ctx.db.get(args.id);
    if (!doc || doc.userId !== userId) throw new Error("Forbidden");
    await ctx.db.patch(args.id, {
      imagesBase64: [...doc.imagesBase64, args.imageBase64],
      updatedAtMs: Date.now(),
    });
  },
});

export const removeImageAt = mutation({
  args: {
    id: v.id("notes"),
    imageIndex: v.number(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) throw new Error("Unauthenticated");
    const doc = await ctx.db.get(args.id);
    if (!doc || doc.userId !== userId) throw new Error("Forbidden");
    if (args.imageIndex < 0 || args.imageIndex >= doc.imagesBase64.length) return;
    const next = [...doc.imagesBase64];
    next.splice(args.imageIndex, 1);
    await ctx.db.patch(args.id, { imagesBase64: next, updatedAtMs: Date.now() });
  },
});

export const remove = mutation({
  args: { id: v.id("notes") },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) throw new Error("Unauthenticated");
    const doc = await ctx.db.get(args.id);
    if (!doc || doc.userId !== userId) return;
    await ctx.db.delete(args.id);
  },
});
