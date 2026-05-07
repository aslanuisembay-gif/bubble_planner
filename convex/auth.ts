import { Password } from "@convex-dev/auth/providers/Password";
import { Email } from "@convex-dev/auth/providers/Email";
import { convexAuth } from "@convex-dev/auth/server";

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [
    Password({
      reset: Email({
        id: "password-reset",
        maxAge: 60 * 15,
        async sendVerificationRequest({ identifier, token }) {
          const apiKey = process.env.AUTH_RESEND_KEY ?? process.env.RESEND_API_KEY;
          const from = process.env.AUTH_FROM ?? process.env.RESEND_FROM;
          if (!apiKey || !from) {
            throw new Error(
              "Password reset is not configured. Set AUTH_RESEND_KEY and AUTH_FROM.",
            );
          }
          const subject = "Bubble Planner password reset code";
          const html = `
            <div style="font-family:Arial,sans-serif;line-height:1.45;color:#111827">
              <p>Reset code for <b>${identifier}</b>:</p>
              <p style="font-size:28px;font-weight:700;letter-spacing:4px;margin:10px 0">${token}</p>
              <p>This code is valid for 15 minutes.</p>
              <p>If you did not request this, ignore this email.</p>
            </div>
          `;
          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${apiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from,
              to: identifier,
              subject,
              html,
            }),
          });
          if (!res.ok) {
            const body = await res.text();
            throw new Error(`Reset email send failed: ${body}`);
          }
        },
      }),
      profile(params) {
        const raw = String(params.email ?? "").trim();
        if (!raw) {
          throw new Error("Введите логин.");
        }
        const email = raw.includes("@")
          ? raw.toLowerCase()
          : `${raw.replace(/[^a-zA-Z0-9._-]/g, "_").replace(/^_|_$/g, "") || "user"}@bubble.local`;
        if (!email.includes("@")) {
          throw new Error("Некорректный логин.");
        }
        return { email };
      },
      validatePasswordRequirements(password: string) {
        const p = String(password).trim();
        if (p.length < 8) {
          throw new Error(
            `Пароль: минимум 8 символов (после trim сейчас ${p.length}).`,
          );
        }
      },
    }),
  ],
});
