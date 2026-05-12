const permissions = require("./permissions");

const allPermissionKeys = permissions.map((permission) => permission.key);

module.exports = [
  {
    id: 1,
    name: "admin",
    label: "Administrator",
    permissions: allPermissionKeys,
  },
  {
    id: 2,
    name: "editor",
    label: "Editor",
    permissions: [
      "authors.read",
      "tags.read",
      "posts.read",
      "posts.create",
      "posts.update",
      "comments.read",
      "comments.create",
      "comments.update",
    ],
  },
  {
    id: 3,
    name: "reader",
    label: "Reader",
    permissions: [
      "authors.read",
      "tags.read",
      "posts.read",
      "comments.read",
    ],
  },
  {
    id: 4,
    name: "author",
    label: "Author",
    permissions: [
      "authors.read",
      "tags.read",
      "posts.read",
      "posts.create",
      "posts.update",
      "comments.read",
      "comments.create",
    ],
  },
];
