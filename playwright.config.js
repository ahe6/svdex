import { defineConfig } from "@playwright/test";

// Browser checks must never target staging/production or use real accounts.
const baseURL = "http://localhost:4080";
export default defineConfig({
  testDir: "./test/browser",
  outputDir: "artifacts/browser-results",
  reporter: [["list"], ["html", { outputFolder: "artifacts/browser-report", open: "never" }]],
  forbidOnly: Boolean(process.env.CI),
  workers: 1,
  retries: 0,
  timeout: 45_000,
  expect: { timeout: 10_000 },
  use: { baseURL, browserName: "chromium", channel: process.env.SVDEX_BROWSER_CHANNEL === "chrome" ? "chrome" : undefined, screenshot: "only-on-failure", trace: "off" },
  projects: [
    { name: "desktop", use: { viewport: { width: 1280, height: 900 } } },
    { name: "tablet", use: { viewport: { width: 900, height: 900 } } },
    { name: "mobile", use: { viewport: { width: 375, height: 844 }, isMobile: true, hasTouch: true } },
    { name: "narrow-mobile", use: { viewport: { width: 320, height: 760 }, isMobile: true, hasTouch: true } },
  ],
});
