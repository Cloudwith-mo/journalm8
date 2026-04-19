import { useState } from "react";
import { authService } from "../services/api";

export function AuthScreen({ onSuccess }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [mode, setMode] = useState("signin"); // signin or signup

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (mode === "signin") {
        await authService.signIn(email, password);
      } else {
        await authService.signUp(email, password);
        await authService.signIn(email, password);
      }
      onSuccess();
    } catch (err) {
      setError(err.message || "Auth failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-white mb-2">JournalM8</h1>
          <p className="text-gray-400">Your AI-powered journal transcriber</p>
        </div>

        <form
          onSubmit={handleSubmit}
          className="bg-gray-800 p-6 rounded-lg space-y-4"
        >
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Email
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2 bg-gray-700 text-white rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
              required
              disabled={loading}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2 bg-gray-700 text-white rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
              required
              disabled={loading}
            />
          </div>

          {error && <div className="text-red-400 text-sm">{error}</div>}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white font-medium py-2 rounded transition"
          >
            {loading
              ? "Loading..."
              : mode === "signin"
                ? "Sign In"
                : "Sign Up"}
          </button>

          <button
            type="button"
            onClick={() => {
              setMode(mode === "signin" ? "signup" : "signin");
              setError("");
            }}
            className="w-full text-blue-400 hover:text-blue-300 text-sm"
          >
            {mode === "signin"
              ? "Don't have an account? Sign up"
              : "Already have an account? Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}
