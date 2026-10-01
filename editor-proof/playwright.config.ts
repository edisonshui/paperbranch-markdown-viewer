import { defineConfig } from "@playwright/test";

const packagedBaseURL = process.env.PAPERBRANCH_EDITOR_CONTRACT_BASE_URL;

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  reporter: [["list"]],
  use: {
    baseURL: packagedBaseURL ?? "http://localhost:5183",
  },
  webServer: packagedBaseURL ? undefined : {
    command: "npx vite --port 5183 --strictPort",
    url: "http://localhost:5183",
    reuseExistingServer: !process.env.CI,
  },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
});
