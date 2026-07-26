const admin = require("firebase-admin/app");
admin.initializeApp();

const newMemberJoinedGroup = require("./new_member_joined_group.js");
exports.newMemberJoinedGroup = newMemberJoinedGroup.newMemberJoinedGroup;
const newMemberJoinedGroupUpdated = require("./new_member_joined_group_updated.js");
exports.newMemberJoinedGroupUpdated =
  newMemberJoinedGroupUpdated.newMemberJoinedGroupUpdated;
const scheduleNotificationsForEachDay = require("./schedule_notifications_for_each_day.js");
exports.scheduleNotificationsForEachDay =
  scheduleNotificationsForEachDay.scheduleNotificationsForEachDay;
const sendFirstSevenDayReminders = require("./send_first_seven_day_reminders.js");
exports.sendFirstSevenDayReminders =
  sendFirstSevenDayReminders.sendFirstSevenDayReminders;
const deleteAllUserData = require("./delete_all_user_data.js");
exports.deleteAllUserData = deleteAllUserData.deleteAllUserData;
const addSearchTermsForUsers = require("./add_search_terms_for_users.js");
exports.addSearchTermsForUsers = addSearchTermsForUsers.addSearchTermsForUsers;
const addSearchTermsForGroups = require("./add_search_terms_for_groups.js");
exports.addSearchTermsForGroups =
  addSearchTermsForGroups.addSearchTermsForGroups;
const cleanInvalidUserGroupEntries = require("./clean_invalid_user_group_entries.js");
exports.cleanInvalidUserGroupEntries =
  cleanInvalidUserGroupEntries.cleanInvalidUserGroupEntries;
const deleteGroupsByCreator = require("./delete_groups_by_creator.js");
exports.deleteGroupsByCreator = deleteGroupsByCreator.deleteGroupsByCreator;
const cleanInvalidChatEntries = require("./clean_invalid_chat_entries.js");
exports.cleanInvalidChatEntries =
  cleanInvalidChatEntries.cleanInvalidChatEntries;
