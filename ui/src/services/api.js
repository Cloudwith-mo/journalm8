const API_ENDPOINT = "https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com";

const COGNITO_CONFIG = {
  userPoolId: "us-east-1_bJcMC6yDw",
  clientId: "4d7p90ejov0chl7sohp4nv856j",
  region: "us-east-1",
  cognitoUrl: "https://cognito-idp.us-east-1.amazonaws.com",
};

export const authService = {
  async signIn(email, password) {
    try {
      const response = await fetch(COGNITO_CONFIG.cognitoUrl + "/", {
        method: "POST",
        headers: {
          "X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
          "Content-Type": "application/x-amz-json-1.1",
        },
        body: JSON.stringify({
          ClientId: COGNITO_CONFIG.clientId,
          AuthFlow: "USER_PASSWORD_AUTH",
          AuthParameters: {
            USERNAME: email,
            PASSWORD: password,
          },
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || data.__type || "Sign in failed");
      }

      if (data.AuthenticationResult?.IdToken) {
        localStorage.setItem("idToken", data.AuthenticationResult.IdToken);
        localStorage.setItem("email", email);
      }

      return data;
    } catch (error) {
      throw new Error(error.message || "Sign in failed");
    }
  },

  async signUp(email, password) {
    try {
      const response = await fetch(COGNITO_CONFIG.cognitoUrl + "/", {
        method: "POST",
        headers: {
          "X-Amz-Target": "AWSCognitoIdentityProviderService.SignUp",
          "Content-Type": "application/x-amz-json-1.1",
        },
        body: JSON.stringify({
          ClientId: COGNITO_CONFIG.clientId,
          Username: email,
          Password: password,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || data.__type || "Sign up failed");
      }

      return data;
    } catch (error) {
      throw new Error(error.message || "Sign up failed");
    }
  },

  signOut() {
    localStorage.removeItem("idToken");
    localStorage.removeItem("email");
  },

  getToken() {
    return localStorage.getItem("idToken");
  },

  getEmail() {
    return localStorage.getItem("email");
  },

  isAuthenticated() {
    return !!localStorage.getItem("idToken");
  },
};

function authHeaders() {
  return {
    Authorization: `Bearer ${authService.getToken()}`,
    "Content-Type": "application/json",
  };
}

export const uploadService = {
  async presignUpload(filename) {
    const response = await fetch(`${API_ENDPOINT}/uploads/presign`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        filename,
        contentType: "image/png",
      }),
    });
    if (!response.ok) throw new Error("Presign failed");
    return await response.json();
  },

  async uploadImage(presignedUrl, file) {
    const response = await fetch(presignedUrl, {
      method: "PUT",
      headers: {
        "Content-Type": "image/png",
      },
      body: file,
    });
    if (response.status !== 200) throw new Error("Upload failed");
    return true;
  },
};

export const entriesService = {
  async getEntries() {
    try {
      const response = await fetch(`${API_ENDPOINT}/entries`, {
        method: "GET",
        headers: authHeaders(),
      });

      if (!response.ok) throw new Error("Failed to fetch entries");
      const data = await response.json();
      return data.entries || [];
    } catch (error) {
      console.error("getEntries error:", error);
      throw error;
    }
  },

  async getEntry(entryId) {
    try {
      const response = await fetch(`${API_ENDPOINT}/entries/${entryId}`, {
        method: "GET",
        headers: authHeaders(),
      });

      if (!response.ok) throw new Error("Failed to fetch entry");
      const data = await response.json();
      return data.entry || data;
    } catch (error) {
      console.error("getEntry error:", error);
      throw error;
    }
  },

  async updateEntryTranscript(entryId, correctedText) {
    try {
      const response = await fetch(`${API_ENDPOINT}/entries/${entryId}`, {
        method: "PUT",
        headers: authHeaders(),
        body: JSON.stringify({
          correctedText,
        }),
      });

      if (!response.ok) throw new Error("Failed to update transcript");
      return true;
    } catch (error) {
      console.error("updateEntryTranscript error:", error);
      throw error;
    }
  },

  async getEntryInsight(entryId) {
    try {
      const response = await fetch(`${API_ENDPOINT}/entries/${entryId}/insight`, {
        method: "GET",
        headers: authHeaders(),
      });
      if (!response.ok) throw new Error("Insight not found");
      return await response.json();
    } catch (error) {
      console.error("getEntryInsight error:", error);
      throw error;
    }
  },
};

export const agentsService = {
  async runWeeklyReflection(weekStart, weekEnd) {
    try {
      const body = {};
      if (weekStart) body.weekStart = weekStart;
      if (weekEnd) body.weekEnd = weekEnd;
      const response = await fetch(`${API_ENDPOINT}/agents/weekly-reflection/run`, {
        method: "POST",
        headers: authHeaders(),
        body: JSON.stringify(body),
      });
      if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        throw new Error(err.message || "Weekly reflection failed");
      }
      return await response.json();
    } catch (error) {
      console.error("runWeeklyReflection error:", error);
      throw error;
    }
  },
};
