import { Password } from "@convex-dev/auth/providers/Password";
import { convexAuth } from "@convex-dev/auth/server";

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [
    Password({
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
