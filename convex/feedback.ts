import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const submit = mutation({
  args: {
    contactType: v.union(v.literal("email"), v.literal("phone")),
    contact: v.string(),
    message: v.string(),
    languageCode: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const contact = args.contact.trim();
    const message = args.message.trim();
    const languageCode = args.languageCode.trim().toLowerCase();
    if (contact.length < 3) {
      throw new Error("Contact is too short");
    }
    if (message.length < 5) {
      throw new Error("Message is too short");
    }
    await ctx.db.insert("feedback", {
      userId: userId ?? "anonymous",
      contactType: args.contactType,
      contact,
      message,
      languageCode,
      createdAtMs: Date.now(),
    });
    return { ok: true as const };
  },
});

