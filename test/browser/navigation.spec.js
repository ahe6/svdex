import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";

let categories;
test.beforeAll(async ({ request }) => {
  const response = await request.get("/site.json");
  expect(response.ok()).toBeTruthy();
  categories = (await response.json()).categories;
  for (const slug of ["offerings", "products", "pre-sales", "discussion", "events"]) {
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
async function expectCatalogHeader(page, title, stacked = false) {
  const header = page.locator(".svdex-catalog-heading");
  await expect(header.getByRole("heading", { name: title, exact: true })).toBeVisible();
  const usesOpenCount = ["Offerings", "Pre-sales"].includes(title);
  await expect(header.locator(".svdex-directory-heading-count")).toHaveText(usesOpenCount ? /^\d+ open items?$/ : /^\d+ items?$/);
  const heading = await header.boundingBox();
  const tabs = await page.locator("#navigation-bar").boundingBox();
  if (stacked) {
    expect(tabs.y).toBeGreaterThanOrEqual(heading.y + heading.height);
    expect(Math.abs(tabs.x - heading.x)).toBeLessThan(2);
  } else {
    expect(tabs.x).toBeGreaterThanOrEqual(heading.x + heading.width);
    expect(Math.abs(tabs.y + tabs.height / 2 - heading.y - heading.height / 2)).toBeLessThan(2);
  }
}
async function expectCatalogActionsBesideTabs(page) {
  const tabs = await page.locator("#navigation-bar").boundingBox();
  for (const selector of [".svdex-filter-trigger", "#create-topic"]) {
    const control = await page.locator(selector).boundingBox();
    expect(Math.abs(control.y + control.height / 2 - tabs.y - tabs.height / 2)).toBeLessThan(3);
  }
}
async function proof(page, info, name) {
  const layout = await page.locator(".list-controls .navigation-container, .directory-controls, #navigation-bar, .navigation-controls, #create-topic, .svdex-company-directory-tools, .svdex-company-search-item, .svdex-company-application, .svdex-filter-trigger, .svdex-discovery-search").evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect();
    const css = getComputedStyle(element);
    return { classes: element.className, box: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, font: css.font, color: css.color, gap: css.gap };
  }).filter(item => item.box.width && item.box.height));
  await info.attach(`${name}-layout`, { body: JSON.stringify(layout, null, 2), contentType: "application/json" });
  await page.screenshot({ path: info.outputPath(`${name}.png`), animations: "disabled" });
  await info.attach(name, { path: info.outputPath(`${name}.png`), contentType: "image/png" });
}

for (const [label, path] of [
  ["Add offering", () => categoryPath("offerings")],
  ["New pre-sale", () => categoryPath("pre-sales")],
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

for (const [label, path, kind] of [
  ["Add product", () => categoryPath("products"), "products"],
  ["Add person", () => "/people", "people"],
  ["Add company", () => "/companies?order=svdex_total_funding", "companies"],
  ["Add fund", () => "/companies?kind=funds&order=svdex_aum", "funds"],
]) {
  test(`guest ${label} opens a GitHub file draft`, async ({ page }) => {
    const editor = `https://github.com/ahe6/svdex/new/main/directory/${kind}`;
    await page.route(`${editor}?*`, route => route.fulfill({ body: "GitHub editor" }));
    await visit(page, path());
    await ready(page);
    await fitsScreen(page);
    await page.getByRole("button", { name: label, exact: true }).click();
    await page.waitForURL(`${editor}?*`);
    const draft = JSON.parse(new URL(page.url()).searchParams.get("value"));
    expect(draft.schema_version).toBe(1);
    expect(draft.sources).toEqual([{ url: "", note: "" }]);
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

test("Offerings navigation opens the Securities directory in place", async ({ page, isMobile }, info) => {
  await visit(page, categoryPath("offerings"));
  await ready(page);
  await expectCatalogHeader(page, "Offerings");
  await expect(page.locator(".svdex-private-access-notice")).toHaveCount(0);
  if (isMobile) await page.getByRole("button", { name: "Latest", exact: true }).click();
  const navigation = isMobile ? page.getByRole("dialog").filter({ has: page.getByRole("link", { name: "All securities", exact: true }) }) : page.locator("#navigation-bar");
  await expect(navigation.getByRole("link", { name: "Latest", exact: true })).toBeVisible();
  await expect(navigation.getByRole("link")).toHaveCount(2);
  await navigation.getByRole("link", { name: "All securities", exact: true }).click();
  await expect(page).toHaveURL(/\/c\/offerings\/\d+\/l\/latest\?svdex_view=directory/);
  await expect(page.getByRole("table", { name: "Securities" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Add offering", exact: true })).toBeVisible();
  await expectCatalogActionsBesideTabs(page);
  await fitsScreen(page);
  expect(await page.title()).not.toMatch(/<\/?span/);
  await proof(page, info, "offering-tabs");
  await page.getByRole("button", { name: "Add offering", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
});

test("Products and Pre-sales have distinct destinations and retain their feed scope", async ({ page, isMobile }, info) => {
  await visit(page, `${categoryPath("products")}/none`);
  await ready(page);
  await expectCatalogHeader(page, "Products", isMobile);
  if (!isMobile) {
    await expect(page.locator("#d-sidebar").getByRole("link", { name: "Products", exact: true })).toHaveAttribute("href", `${categoryPath("products")}/none`);
    const presales = page.locator("#d-sidebar").getByRole("link", { name: "Pre-sales", exact: true });
    await expect(presales).toHaveAttribute("href", /\/pre-sales\/\d+$/);
  }
  if (isMobile) await page.getByRole("button", { name: "Latest", exact: true }).click();
  await page.getByRole("link", { name: "All products", exact: true }).click();
  await expect(page).toHaveURL(/\/none\/l\/latest\?svdex_view=directory/);
  await expect(page.getByRole("table", { name: "Products" })).toBeVisible();
  await expectCatalogHeader(page, "Products", isMobile);
  await fitsScreen(page);
  await expectCatalogActionsBesideTabs(page);
  await proof(page, info, "products-navigation");

  if (isMobile) await page.getByRole("button", { name: "All products", exact: true }).click();
  await page.locator(isMobile ? '[role="dialog"]' : "#navigation-bar")
    .getByRole("link", { name: "Top", exact: true }).click();
  await expect(page).toHaveURL(/\/none\/l\/top(?:\?|$)/);
  const period = page.locator(".top-lists .period-chooser-header");
  await period.click();
  await page.locator(".top-lists").getByRole("menuitemradio", { name: /^Month/ }).click();
  await expect(page).toHaveURL(/\/none\/l\/top\?.*period=monthly/);
  await expect(period).toContainText("Month");
  await expectCatalogHeader(page, "Products", isMobile);
  await expectCatalogActionsBesideTabs(page);
  await fitsScreen(page);

  await visit(page, categoryPath("pre-sales"));
  await ready(page);
  await expectCatalogHeader(page, "Pre-sales");
  if (isMobile) await page.getByRole("button", { name: "Latest", exact: true }).click();
  const presaleTab = isMobile ? page.getByRole("dialog").getByRole("link", { name: "All pre-sales", exact: true }) :
    page.locator("#navigation-bar").getByRole("link", { name: "All pre-sales", exact: true });
  await presaleTab.click();
  await expect(page).toHaveURL(/\/pre-sales\/\d+\/l\/latest\?svdex_view=directory/);
  await expect(page.getByRole("table", { name: "Pre-sale products" })).toBeVisible();
  await expect(page.getByRole("button", { name: "New pre-sale", exact: true })).toBeVisible();
  await fitsScreen(page);
  await expectCatalogActionsBesideTabs(page);
});

test("Companies, Funds, Products, and People have direct sidebar links", async ({ page, isMobile }) => {
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await visit(page, "/latest");
  await ready(page);
  const menu = page.getByRole("button", { name: "Navigation menu", exact: true });
  if (isMobile) await menu.click();
  const sidebar = page.locator(".sidebar-sections:visible");
  const destinations = [
    ["Companies", "/company-directory"],
    ["Funds", "/fund-directory"],
    ["Products", `${categoryPath("products")}/none`],
    ["People", "/person-directory"],
  ];
  await expect(sidebar.locator('[data-section-name="svdex-directory"]')).toHaveCount(0);
  await expect(sidebar.getByRole("link", { name: /^(Pre-sales|Events|Discussions|Companies|Funds|Products|People)$/ }))
    .toHaveText(["Pre-sales", "Events", "Discussions", ...destinations.map(([name]) => name)]);

  for (const [name, path] of destinations) {
    const link = sidebar.getByRole("link", { name, exact: true });
    await link.click();
    await expect(page).toHaveURL(url => url.pathname === path);
    await expect(page.getByRole("heading", { name, exact: true })).toBeVisible();
    await fitsScreen(page);
    if (!isMobile) await expect(link).toHaveClass(/active/);
    else if (name !== "People") await menu.click();
  }
  expect(errors).toEqual([]);
});

test("guest directory interest goes to login", async ({ page }) => {
  await visit(page, "/company-directory");
  await ready(page);
  await page.getByRole("button", {name:"Indicate interest",exact:true}).click();
  await expect(page).toHaveURL(/\/login$/);
});

function localMemberScript(source) {
  return execFileSync("docker", ["exec", "-i", "-u", "discourse", "miscdex-forum", "bash", "-lc",
    "cd /var/www/discourse && bundle exec rails runner --skip-executor -"], {
    input: `abort "Local browser fixtures only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"\n${source}`,
    encoding: "utf8", timeout: 25_000,
  });
}

test("signed-in directory interest uses one form and offerings use the native composer", async ({ page }, info) => {
  test.skip(info.project.name !== "desktop", "Native sign-in fixture runs once.");
  test.setTimeout(90_000);
  const output = localMemberScript(`
    suffix = SecureRandom.hex(4)
    password = SecureRandom.hex(24)
    member = User.create!(username: "svdex_test_#{suffix}", email: "svdex_test_#{suffix}@example.invalid",
      password: password, active: true, approved: true, trust_level: 2)
    member.email_tokens.update_all(confirmed: true)
    puts JSON.generate(id: member.id, username: member.username, password: password)
  `);
  const member = JSON.parse(output.trim().split("\n").at(-1));
  try {
    await visit(page, "/login");
    await page.getByRole("textbox", { name: /email \/ username/i }).fill(member.username);
    await page.getByLabel("Password", { exact: true }).fill(member.password);
    await page.getByRole("button", { name: "Log In", exact: true }).click();
    await expect(page).not.toHaveURL(/\/login$/);

    await visit(page, categoryPath("discussion"));
    await expect(page.locator('[data-list-item-name="my-posts"] + [data-list-item-name="svdex-my-interest"] + [data-list-item-name="svdex-bookmarks"]')).toBeVisible();
    await page.locator("#navigation-bar").getByRole("link", { name: "Chat", exact: true }).click();
    await expect(page).toHaveURL(/\/chat\/c\//);
    await page.goBack();
    const messages = page.locator(".chat-header-icon a");
    await expect(messages).toHaveAttribute("href", "/chat/direct-messages");
    await messages.click();
    await expect(page).toHaveURL(/\/chat\/direct-messages$/);
    await expect(page.locator(".full-page-chat .c-routes.--direct-messages")).toBeVisible();

    await visit(page, "/company-directory");
    await page.getByRole("button", { name: "Indicate interest", exact: true }).click();
    const modal = page.getByRole("dialog", { name: "Indicate interest", exact: true });
    await expect(modal.getByLabel("Amount (USD)")).toBeVisible();
    await expect(modal.getByText("Direction", { exact: true })).toBeVisible();
    await expect(modal.getByRole("button", { name: "Continue", exact: true })).toHaveCount(0);
    await expect(modal.getByRole("button", { name: "Save buy interest", exact: true })).toBeDisabled();

    await visit(page, `${categoryPath("offerings")}/l/latest?svdex_view=directory`);
    await page.getByRole("button", { name: "Add offering", exact: true }).click();
    await expect(page.locator("#reply-control")).toBeVisible();
    await expect(page).toHaveURL(/svdex_view=directory/);

    await visit(page, categoryPath("pre-sales"));
    await page.getByRole("button", { name: "New pre-sale", exact: true }).click();
    await expect(page.locator("#reply-control .svdex-presale-fields")).toBeVisible();
  } finally {
    localMemberScript(`
      member = User.find_by(id: ${Number(member.id)})
      if member && member.username.start_with?("svdex_test_") && member.email.end_with?("@example.invalid")
        UserDestroyer.new(Discourse.system_user).destroy(member, { context: "SVDEX browser fixture" })
      end
    `);
  }
});
