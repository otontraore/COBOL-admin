const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
const yaml = require("js-yaml");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

function publicUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  const role = db.roles.find((candidate) => candidate.id === user.roleId);
  return {
    ...safeUser,
    roleLabel: role ? role.label : "",
  };
}

function currentSession(req) {
  const cookie = req.headers.cookie || "";
  const sid = cookie
    .split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith("sid="));
  if (!sid) return null;
  return sessions.get(sid.slice(4));
}

function currentUser(req) {
  const session = currentSession(req);
  if (!session) return null;
  return db.users.find((user) => user.id === session.userId) || null;
}

function userRole(user) {
  return db.roles.find((role) => role.id === user.roleId) || null;
}

function authPayload(user) {
  const role = userRole(user);
  return {
    user: publicUser(user),
    role,
    permissions: role ? role.permissions : [],
  };
}

function publicPost(post) {
  const author = db.users.find((user) => user.id === post.authorId);
  const tagNames = (post.tagIds || [])
    .map((tagId) => db.tags.find((tag) => tag.id === Number(tagId)))
    .filter(Boolean)
    .map((tag) => tag.name);

  return {
    id: post.id,
    title: post.title,
    body: post.body,
    authorDisplayName: author ? author.displayName : "",
    tagNames,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
  };
}

// --- In-memory data with seed ---
const db = {
  tags: require("./fixtures/tags"),
  posts: require("./fixtures/posts"),
  comments: require("./fixtures/comments"),
  permissions: require("./fixtures/permissions"),
  roles: require("./fixtures/roles"),
  users: require("./fixtures/users"),
};

const counters = {
  tags: Math.max(...db.tags.map((item) => item.id), 0),
  posts: Math.max(...db.posts.map((item) => item.id), 0),
  comments: Math.max(...db.comments.map((item) => item.id), 0),
  permissions: Math.max(...db.permissions.map((item) => item.id), 0),
  roles: Math.max(...db.roles.map((item) => item.id), 0),
  users: Math.max(...db.users.map((item) => item.id), 0),
};

const sessions = new Map();

// --- Generic CRUD helper ---
function crud(resource, timestamped = false) {
  const router = express.Router();

  router.get("/", (req, res) => {
    let items = db[resource];
    if (req.query.postId) {
      items = items.filter((i) => i.postId === Number(req.query.postId));
    }
    const total = items.length;
    if (req.query.perPage) {
      const perPage = Math.max(1, Number(req.query.perPage) || 10);
      const page = Math.max(1, Number(req.query.page) || 1);
      const start = (page - 1) * perPage;
      items = items.slice(start, start + perPage);
      res.set("X-Total-Count", String(total));
    }
    res.json(resource === "users" ? items.map(publicUser) : items);
  });

  router.get("/:id", (req, res) => {
    const item = db[resource].find((i) => i.id === Number(req.params.id));
    item
      ? res.json(resource === "users" ? publicUser(item) : item)
      : res.status(404).json({ error: "Not found" });
  });

  router.post("/", (req, res) => {
    const now = new Date().toISOString();
    const item = { id: ++counters[resource], ...req.body };
    if (timestamped) {
      item.createdAt = now;
      item.updatedAt = now;
    }
    db[resource].push(item);
    res.status(201).json(resource === "users" ? publicUser(item) : item);
  });

  router.put("/:id", (req, res) => {
    const idx = db[resource].findIndex((i) => i.id === Number(req.params.id));
    if (idx === -1) return res.status(404).json({ error: "Not found" });
    const now = new Date().toISOString();
    db[resource][idx] = {
      ...db[resource][idx],
      ...req.body,
      id: db[resource][idx].id,
    };
    if (timestamped) db[resource][idx].updatedAt = now;
    res.json(resource === "users" ? publicUser(db[resource][idx]) : db[resource][idx]);
  });

  router.delete("/:id", (req, res) => {
    const idx = db[resource].findIndex((i) => i.id === Number(req.params.id));
    if (idx === -1) return res.status(404).json({ error: "Not found" });
    db[resource].splice(idx, 1);
    res.status(204).end();
  });

  return router;
}

// --- Routes ---
app.get("/authors", (req, res) => {
  const authorRole = db.roles.find((role) => role.name === "author");
  let items = authorRole
    ? db.users.filter((user) => user.roleId === authorRole.id).map(publicUser)
    : [];
  const total = items.length;
  if (req.query.perPage) {
    const perPage = Math.max(1, Number(req.query.perPage) || 10);
    const page = Math.max(1, Number(req.query.page) || 1);
    const start = (page - 1) * perPage;
    items = items.slice(start, start + perPage);
    res.set("X-Total-Count", String(total));
  }
  res.json(items);
});

app.get("/authors/:id", (req, res) => {
  const authorRole = db.roles.find((role) => role.name === "author");
  const item = authorRole
    ? db.users.find(
        (user) => user.id === Number(req.params.id) && user.roleId === authorRole.id,
      )
    : null;
  item ? res.json(publicUser(item)) : res.status(404).json({ error: "Not found" });
});
app.use("/tags", crud("tags"));
app.get("/posts", (req, res) => {
  let items = db.posts.map(publicPost);
  const total = items.length;
  if (req.query.perPage) {
    const perPage = Math.max(1, Number(req.query.perPage) || 10);
    const page = Math.max(1, Number(req.query.page) || 1);
    const start = (page - 1) * perPage;
    items = items.slice(start, start + perPage);
    res.set("X-Total-Count", String(total));
  }
  res.json(items);
});

app.get("/posts/:id", (req, res) => {
  const item = db.posts.find((post) => post.id === Number(req.params.id));
  item ? res.json(publicPost(item)) : res.status(404).json({ error: "Not found" });
});
app.use("/posts", crud("posts", true));
app.use("/comments", crud("comments", true));
app.use("/permissions", crud("permissions"));
app.use("/roles", crud("roles"));
app.use("/users", crud("users", true));

app.post("/auth/login", (req, res) => {
  const username = String(req.body.username || "").trim();
  const password = String(req.body.password || "");
  const user = db.users.find(
    (candidate) => candidate.username === username && candidate.password === password,
  );

  if (!user) {
    return res.status(401).json({ error: "Invalid credentials" });
  }

  const sessionId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  sessions.set(sessionId, { userId: user.id, createdAt: new Date().toISOString() });
  res.json({ sessionId, ...authPayload(user) });
});

app.post("/auth/logout", (req, res) => {
  const session = currentSession(req);
  if (session) {
    for (const [sessionId, storedSession] of sessions) {
      if (storedSession === session) sessions.delete(sessionId);
    }
  }
  res.status(204).end();
});

app.get("/auth/me", (req, res) => {
  const user = currentUser(req);
  if (!user) return res.status(401).json({ error: "Not authenticated" });
  res.json(authPayload(user));
});

// --- OpenAPI spec & Swagger UI ---
const specPath = path.join(__dirname, "openapi.json");
const spec = yaml.load(fs.readFileSync(specPath, "utf8"));
app.use("/docs", swaggerUi.serve, swaggerUi.setup(spec));
app.get("/openapi.json", (_req, res) => {
  res.json(spec);
});

// --- Start ---
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API running at http://localhost:${PORT}`);
  console.log(`Swagger UI at http://localhost:${PORT}/docs`);
});
