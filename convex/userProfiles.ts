import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getMine = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      return null;
    }
    return await ctx.db
      .query("userProfiles")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();
  },
});

export const upsertMine = mutation({
  args: {
    displayName: v.string(),
    avatarBase64: v.optional(v.string()),
    clearAvatar: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }
    const now = Date.now();
    const existing = await ctx.db
      .query("userProfiles")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .unique();

    const avatarBase64 = args.clearAvatar
      ? undefined
      : (args.avatarBase64 ?? existing?.avatarBase64);

    if (existing) {
      await ctx.db.patch(existing._id, {
        displayName: args.displayName,
        avatarBase64,
        updatedAtMs: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("userProfiles", {
      userId,
      displayName: args.displayName,
      avatarBase64,
      updatedAtMs: now,
    });
  },
});
