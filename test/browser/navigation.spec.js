import { test, expect } from "@playwright/test";

let categories;
test.beforeAll(async ({ request }) => {
  const response = await request.get("/site.json");
  expect(response.ok()).toBeTruthy();
  categories = (await response.json()).categories;
  for (const slug of ["offerings", "products", "discussion", "events"]) {
    expect(categories.find(category => category.slug === slug), `Configured ${slug} category`).toBeTruthy();
  }
});
// Native directory/bootstrap endpoints limit one IP even across fresh guest
// contexts. Pace the suite instead of disabling limits or retrying app errors.
test.afterEach(async () => { await new Promise(resolve => setTimeout(resolve, 3000)); });
const categoryPath = slug => {
  const category = categories.find(item => item.slug === slug);
  return `/c/${slug}/${category.id}`;
};
async function visit(page, path) {
  // Fresh guest contexts share one loopback IP. Respect nginx throttling rather
  // than weakening the forum's rate limits or retrying arbitrary app failures.
  for (let attempt = 0; attempt < 3; attempt++) {
    const response = await page.goto(path);
    if (response.status() !== 429) {
      expect(response.ok(), `Navigation to ${path}`).toBeTruthy();
      return;
    }
    const seconds = Number(response.headers()["retry-after"]);
    await new Promise(resolve => setTimeout(resolve, Number.isFinite(seconds) && seconds > 0 ? Math.min(seconds, 20) * 1000 : 15_000));
  }
  throw new Error(`Loopback rate limit prevented navigation to ${path}`);
}
async function ready(page) {
  await expect(page.locator(".d-header")).toBeVisible();
  await expect(page.locator(".loading-container:visible .spinner")).toHaveCount(0);
}
async function fitsScreen(page) {
  const { width, scroll } = await page.evaluate(() => ({ width: innerWidth, scroll: document.documentElement.scrollWidth }));
  expect(scroll, "The page should not overflow horizontally").toBeLessThanOrEqual(width + 1);
}
async function proof(page, info, name) {
  const layout = await page.locator(".list-controls .navigation-container, .directory-controls, #navigation-bar, .navigation-controls, #create-topic, .svdex-company-directory-tools, .svdex-company-search-item, .svdex-company-application, .svdex-filter-trigger, .svdex-discovery-search").evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    const css = getComputedStyle(element);
    return { classes: element.className, box: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, font: css.font, color: css.color, gap: css.gap };
  }).filter(item => item.box.width && item.box.height));
  await info.attach(`${name}-layout`, { body: JSON.stringify(layout, null, 2), contentType: "application/json" });
  await page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true, animations: "disabled" });
  await info.attach(name, { path: info.outputPath(`${name}.png`), contentType: "image/png" });
}

for (const [label, path] of [
  ["Add product", () => categoryPath("products")],
  ["Add offering", () => categoryPath("offerings")],
  ["Add person", () => "/people"],
  ["Add company", () => "/companies?order=svdex_total_funding"],
  ["Add fund", () => "/companies?kind=funds&order=svdex_aum"],
  ["New Topic", () => categoryPath("discussion")],
  ["New Event", () => categoryPath("events")],
]) {
  test(`guest ${label} stays visible and opens /login directly`, async ({ page }, info) => {
    const errors = [];
    page.on("pageerror", error => errors.push(error.message));
    await visit(page, path());
    await ready(page);
    const button = page.getByRole("button", { name: label, exact: true });
    await expect(button).toBeVisible();
    await fitsScreen(page);
    await proof(page, info, label.toLowerCase().replaceAll(" ", "-"));
    await button.click();
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByRole("heading", { name: "Welcome back", exact: true })).toBeVisible();
    await expect(page.locator(".d-modal")).toHaveCount(0);
    expect(errors).toEqual([]);
  });
}

test("private-access badge uses onboarding URL without a fabricated category route", async ({ page }, info) => {
  await visit(page, "/all-forums");
  await ready(page);
  const privateBadge = page.locator('a.badge-category__wrapper').filter({ hasText: "Private offerings" });
  await expect(privateBadge).toHaveCount(1);
  await expect(privateBadge).toHaveAttribute("href", "/private-offerings");
  await expect(page.locator('a[href*="/c/"][href*="svdex-private-access-info"]')).toHaveCount(0);
  await fitsScreen(page);
  await proof(page, info, "overview-private-access");
  await privateBadge.click();
  await expect(page).toHaveURL(/\/private-offerings$/);
});

test("Offerings navigation separates Latest, Activity and Top", async ({ page, isMobile }, info) => {
  await visit(page, categoryPath("offerings"));
  await ready(page);
  if (isMobile) await page.getByRole("button", { name: "Latest", exact: true }).click();
  const navigation = isMobile ? page.getByRole("dialog").filter({ has: page.getByRole("link", { name: "Top", exact: true }) }) : page.locator("#navigation-bar");
  await expect(navigation.getByRole("link", { name: "Latest", exact: true })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "Top", exact: true })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "Activity", exact: true })).toBeVisible();
  await expect(navigation.getByRole("link")).toHaveCount(3);
  expect(await page.title()).not.toMatch(/<\/?span/);
  await proof(page, info, "offering-tabs");
});

test("Products availability selector survives sort changes and browser Back", async ({ page, isMobile }, info) => {
  await visit(page, categoryPath("products"));
  await ready(page);
  const chip = page.locator(".svdex-product-status:visible").getByRole("button", {name:"Pre-sales",exact:true});
  await chip.click();
  await expect(page).toHaveURL(/svdex_presales=1/);
  if (isMobile) await page.getByRole("button", { name: "Latest", exact: true }).click();
  await page.getByRole("link", { name: "Activity", exact: true }).click();
  await expect(page).toHaveURL(/svdex_view=activity/);
  await expect(chip).toHaveAttribute("aria-pressed", "true");
  await page.goBack();
  await expect(chip).toHaveAttribute("aria-pressed", "true");
  await fitsScreen(page);
  await proof(page, info, "products-availability");
});

test("product type filter keeps search and clears back to combined catalog", async ({ page }, info) => {
  await visit(page, `${categoryPath("products")}?search=research`);
  await ready(page);
  await page.getByRole("button", { name: /^Filters(?: \(.+\))?$/ }).click();
  let modal = page.getByRole("dialog", { name: "Filters", exact: true });
  await modal.getByText("All products", { exact: true }).click();
  await page.getByRole("menuitemradio", { name: "Pre-sales", exact: true }).click();
  await expect(page).toHaveURL(/svdex_presales=1/);
  expect(new URL(page.url()).searchParams.get("search")).toBe("research");
  await page.getByRole("button", { name: /^Filters(?: \(.+\))?$/ }).click();
  modal = page.getByRole("dialog", { name: "Filters", exact: true });
  await modal.getByRole("button", { name: "Clear filters", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`${categoryPath("products")}/l/latest$`));
  await expect(page.getByRole("button", { name: "Filters", exact: true })).toBeVisible();
  await fitsScreen(page);
  await proof(page, info, "products-combined");
});

test("directory interest uses one form for organization, direction and amount", async ({ page }) => {
  await visit(page, "/company-directory");
  await ready(page);
  await page.getByRole("button", {name:"Add interest",exact:true}).click();
  // Guests use the same login route as other directory actions.
  if (new URL(page.url()).pathname === "/login") return;
  const modal = page.getByRole("dialog", {name:"Add interest",exact:true});
  await expect(modal.getByLabel("Amount (USD)")).toBeVisible();
  await expect(modal.getByText("Direction", {exact:true})).toBeVisible();
  await expect(modal.getByRole("button", {name:"Continue",exact:true})).toHaveCount(0);
  await expect(modal.getByRole("button", {name:"Save buy interest",exact:true})).toBeDisabled();
});
