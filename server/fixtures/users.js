const baseDate = new Date("2025-01-01T09:00:00.000Z");

const timestamp = (offset) =>
  new Date(baseDate.getTime() + offset * 86400000).toISOString();

const staff = [
  {
    id: 1,
    username: "admin",
    password: "admin",
    displayName: "Admin",
    roleId: 1,
  },
  {
    id: 2,
    username: "editor",
    password: "editor",
    displayName: "Editor",
    roleId: 2,
  },
  {
    id: 3,
    username: "reader",
    password: "reader",
    displayName: "Reader",
    roleId: 3,
  },
];

const authors = Array.from({ length: 100 }, (_, index) => ({
  id: index + 4,
  username: `author${index + 1}`,
  password: "author",
  displayName: `Author ${index + 1}`,
  roleId: 4,
}));

module.exports = [...staff, ...authors].map((user, index) => ({
  ...user,
  createdAt: timestamp(index),
  updatedAt: timestamp(index),
}));
