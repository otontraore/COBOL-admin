const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
const yaml = require("js-yaml");
const fs = require("fs");
const path = require("path");

const app = express();

app.use(
    cors({
        origin: true,
        credentials: true,
        exposedHeaders: ["X-Total-Count"],
    }),
);
app.use(express.json());

// --- In-memory data with seed ---
const db = {
    tags: require("./fixtures/tags"),
    posts: require("./fixtures/posts"),
    comments: require("./fixtures/comments"),
    permissions: require("./fixtures/permissions"),
    roles: require("./fixtures/roles"),
    users: require("./fixtures/users"),
};

const counters = Object.fromEntries(
    Object.entries(db).map(([resource, items]) => [
        resource,
        Math.max(...items.map((item) => item.id), 0),
    ]),
);

const sessions = new Map();

function publicUser(user) {
    if (!user) return null;

    const { password, ...safeUser } = user;
    const role = db.roles.find((candidate) => candidate.id === user.roleId);

    return {
        ...safeUser,
        roleLabel: role ? role.label : "",
    };
}

function userRole(user) {
    if (!user) return null;

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
        ...post,
        authorDisplayName: author ? author.displayName : "",
        tagNames,
    };
}

function readCookie(req, name) {
    const cookieHeader = String(req.headers.cookie || "");

    return cookieHeader
        .split(";")
        .map((part) => part.trim())
        .find((part) => part.startsWith(`${name}=`))
        ?.slice(name.length + 1);
}

function setSessionCookie(res, sessionId) {
    res.cookie("sid", sessionId, {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
    });
}

function clearSessionCookie(res) {
    res.clearCookie("sid", {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
    });
}

function currentSession(req) {
    const sid = readCookie(req, "sid");

    if (!sid) return null;

    return sessions.get(decodeURIComponent(sid)) || null;
}

function currentUser(req) {
    const session = currentSession(req);

    if (!session) return null;

    return db.users.find((user) => user.id === session.userId) || null;
}

function listWithPagination(req, res, items) {
    const total = items.length;

    if (req.query.perPage) {
        const perPage = Math.max(1, Number(req.query.perPage) || 10);
        const page = Math.max(1, Number(req.query.page) || 1);
        const start = (page - 1) * perPage;

        res.set("X-Total-Count", String(total));

        return items.slice(start, start + perPage);
    }

    return items;
}

// --- Generic CRUD helper ---
function crud(resource, timestamped = false, presenter = (item) => item) {
    const router = express.Router();

    router.get("/", (req, res) => {
        let items = db[resource];

        if (req.query.postId) {
            items = items.filter((item) => item.postId === Number(req.query.postId));
        }

        res.json(listWithPagination(req, res, items).map(presenter));
    });

    router.get("/:id", (req, res) => {
        const item = db[resource].find((candidate) => candidate.id === Number(req.params.id));

        if (!item) {
            return res.status(404).json({ error: "Not found" });
        }

        return res.json(presenter(item));
    });

    router.post("/", (req, res) => {
        const now = new Date().toISOString();
        const item = {
            id: ++counters[resource],
            ...req.body,
        };

        if (timestamped) {
            item.createdAt = now;
            item.updatedAt = now;
        }

        db[resource].push(item);

        res.status(201).json(presenter(item));
    });

    router.put("/:id", (req, res) => {
        const idx = db[resource].findIndex(
            (candidate) => candidate.id === Number(req.params.id),
        );

        if (idx === -1) {
            return res.status(404).json({ error: "Not found" });
        }

        const now = new Date().toISOString();

        db[resource][idx] = {
            ...db[resource][idx],
            ...req.body,
            id: db[resource][idx].id,
        };

        if (timestamped) {
            db[resource][idx].updatedAt = now;
        }

        return res.json(presenter(db[resource][idx]));
    });

    router.delete("/:id", (req, res) => {
        const idx = db[resource].findIndex(
            (candidate) => candidate.id === Number(req.params.id),
        );

        if (idx === -1) {
            return res.status(404).json({ error: "Not found" });
        }

        db[resource].splice(idx, 1);

        return res.status(204).end();
    });

    return router;
}

// --- Routes ---
app.get("/authors", (req, res) => {
    const authorRole = db.roles.find((role) => role.name === "author");
    const items = authorRole
        ? db.users.filter((user) => user.roleId === authorRole.id).map(publicUser)
        : [];

    res.json(listWithPagination(req, res, items));
});

app.get("/authors/:id", (req, res) => {
    const authorRole = db.roles.find((role) => role.name === "author");
    const item = authorRole
        ? db.users.find(
              (user) =>
                  user.id === Number(req.params.id) &&
                  user.roleId === authorRole.id,
          )
        : null;

    if (!item) {
        return res.status(404).json({ error: "Not found" });
    }

    return res.json(publicUser(item));
});

app.use("/tags", crud("tags"));
app.use("/posts", crud("posts", true, publicPost));
app.use("/comments", crud("comments", true));
app.use("/permissions", crud("permissions"));
app.use("/roles", crud("roles"));
app.use("/users", crud("users", true, publicUser));

app.post("/auth/login", (req, res) => {
    const username = String(req.body.username || "").trim();
    const password = String(req.body.password || "");
    const user = db.users.find(
        (candidate) =>
            candidate.username === username && candidate.password === password,
    );

    if (!user) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    const sessionId = crypto.randomUUID();

    sessions.set(sessionId, {
        userId: user.id,
        createdAt: new Date().toISOString(),
    });
    setSessionCookie(res, sessionId);

    return res.json(authPayload(user));
});

app.post("/auth/logout", (req, res) => {
    const sid = readCookie(req, "sid");

    if (sid) {
        sessions.delete(decodeURIComponent(sid));
    }

    clearSessionCookie(res);

    return res.status(204).end();
});

app.get("/auth/me", (req, res) => {
    const user = currentUser(req);

    if (!user) {
        return res.status(401).json({ error: "Not authenticated" });
    }

    return res.json(authPayload(user));
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

if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`API running at http://localhost:${PORT}`);
        console.log(`Swagger UI at http://localhost:${PORT}/docs`);
    });
}

module.exports = app;
