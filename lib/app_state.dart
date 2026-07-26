import 'package:flutter/material.dart';
import 'flutter_flow/request_manager.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _showOnboard = prefs.getBool('ff_showOnboard') ?? _showOnboard;
    });
    _safeInit(() {
      _noParentCategory =
          prefs.getString('ff_noParentCategory')?.ref ?? _noParentCategory;
    });
    _safeInit(() {
      _eulaAccepted = prefs.getBool('ff_eulaAccepted') ?? _eulaAccepted;
    });
    _safeInit(() {
      _eulaagreement = prefs.getString('ff_eulaagreement') ?? _eulaagreement;
    });
    _safeInit(() {
      _marksUserId = prefs.getString('ff_marksUserId')?.ref ?? _marksUserId;
    });
    _safeInit(() {
      _showWelcomeTooltip =
          prefs.getBool('ff_showWelcomeTooltip') ?? _showWelcomeTooltip;
    });
    _safeInit(() {
      _showFirstHabitTooltip =
          prefs.getInt('ff_showFirstHabitTooltip') ?? _showFirstHabitTooltip;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  bool _showOnboard = false;
  bool get showOnboard => _showOnboard;
  set showOnboard(bool value) {
    _showOnboard = value;
    prefs.setBool('ff_showOnboard', value);
  }

  int _checkinSliderValue = 1;
  int get checkinSliderValue => _checkinSliderValue;
  set checkinSliderValue(int value) {
    _checkinSliderValue = value;
  }

  DocumentReference? _tempHabitRef;
  DocumentReference? get tempHabitRef => _tempHabitRef;
  set tempHabitRef(DocumentReference? value) {
    _tempHabitRef = value;
  }

  List<GroupMembershipStatus> _ownerLeaderMemberTypes = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  List<GroupMembershipStatus> get ownerLeaderMemberTypes =>
      _ownerLeaderMemberTypes;
  set ownerLeaderMemberTypes(List<GroupMembershipStatus> value) {
    _ownerLeaderMemberTypes = value;
  }

  void addToOwnerLeaderMemberTypes(GroupMembershipStatus value) {
    ownerLeaderMemberTypes.add(value);
  }

  void removeFromOwnerLeaderMemberTypes(GroupMembershipStatus value) {
    ownerLeaderMemberTypes.remove(value);
  }

  void removeAtIndexFromOwnerLeaderMemberTypes(int index) {
    ownerLeaderMemberTypes.removeAt(index);
  }

  void updateOwnerLeaderMemberTypesAtIndex(
    int index,
    GroupMembershipStatus Function(GroupMembershipStatus) updateFn,
  ) {
    ownerLeaderMemberTypes[index] = updateFn(_ownerLeaderMemberTypes[index]);
  }

  void insertAtIndexInOwnerLeaderMemberTypes(
      int index, GroupMembershipStatus value) {
    ownerLeaderMemberTypes.insert(index, value);
  }

  bool _shouldMoveToActiveHabits = false;
  bool get shouldMoveToActiveHabits => _shouldMoveToActiveHabits;
  set shouldMoveToActiveHabits(bool value) {
    _shouldMoveToActiveHabits = value;
  }

  DocumentReference? _tempReminderRef;
  DocumentReference? get tempReminderRef => _tempReminderRef;
  set tempReminderRef(DocumentReference? value) {
    _tempReminderRef = value;
  }

  DocumentReference? _noParentCategory =
      FirebaseFirestore.instance.doc('/categories/0');
  DocumentReference? get noParentCategory => _noParentCategory;
  set noParentCategory(DocumentReference? value) {
    _noParentCategory = value;
    value != null
        ? prefs.setString('ff_noParentCategory', value.path)
        : prefs.remove('ff_noParentCategory');
  }

  List<DocumentReference> _localContactUsers = [];
  List<DocumentReference> get localContactUsers => _localContactUsers;
  set localContactUsers(List<DocumentReference> value) {
    _localContactUsers = value;
  }

  void addToLocalContactUsers(DocumentReference value) {
    localContactUsers.add(value);
  }

  void removeFromLocalContactUsers(DocumentReference value) {
    localContactUsers.remove(value);
  }

  void removeAtIndexFromLocalContactUsers(int index) {
    localContactUsers.removeAt(index);
  }

  void updateLocalContactUsersAtIndex(
    int index,
    DocumentReference Function(DocumentReference) updateFn,
  ) {
    localContactUsers[index] = updateFn(_localContactUsers[index]);
  }

  void insertAtIndexInLocalContactUsers(int index, DocumentReference value) {
    localContactUsers.insert(index, value);
  }

  DocumentReference? _tempActivityRef;
  DocumentReference? get tempActivityRef => _tempActivityRef;
  set tempActivityRef(DocumentReference? value) {
    _tempActivityRef = value;
  }

  bool _eulaAccepted = false;
  bool get eulaAccepted => _eulaAccepted;
  set eulaAccepted(bool value) {
    _eulaAccepted = value;
    prefs.setBool('ff_eulaAccepted', value);
  }

  String _eulaagreement = 'eula_agreement';
  String get eulaagreement => _eulaagreement;
  set eulaagreement(String value) {
    _eulaagreement = value;
    prefs.setString('ff_eulaagreement', value);
  }

  DocumentReference? _marksUserId =
      FirebaseFirestore.instance.doc('/users/hUJlCsyrI1SrhcRv4fJ3j8p2noF3');
  DocumentReference? get marksUserId => _marksUserId;
  set marksUserId(DocumentReference? value) {
    _marksUserId = value;
    value != null
        ? prefs.setString('ff_marksUserId', value.path)
        : prefs.remove('ff_marksUserId');
  }

  DocumentReference? _selectedChatMessage;
  DocumentReference? get selectedChatMessage => _selectedChatMessage;
  set selectedChatMessage(DocumentReference? value) {
    _selectedChatMessage = value;
  }

  bool _showWelcomeTooltip = true;
  bool get showWelcomeTooltip => _showWelcomeTooltip;
  set showWelcomeTooltip(bool value) {
    _showWelcomeTooltip = value;
    prefs.setBool('ff_showWelcomeTooltip', value);
  }

  /// 0, never shown
  /// 1, show
  /// 2, never show again
  int _showFirstHabitTooltip = 0;
  int get showFirstHabitTooltip => _showFirstHabitTooltip;
  set showFirstHabitTooltip(int value) {
    _showFirstHabitTooltip = value;
    prefs.setInt('ff_showFirstHabitTooltip', value);
  }

  final _userDocQueryManager = FutureRequestManager<UsersRecord>();
  Future<UsersRecord> userDocQuery({
    String? uniqueQueryKey,
    bool? overrideCache,
    required Future<UsersRecord> Function() requestFn,
  }) =>
      _userDocQueryManager.performRequest(
        uniqueQueryKey: uniqueQueryKey,
        overrideCache: overrideCache,
        requestFn: requestFn,
      );
  void clearUserDocQueryCache() => _userDocQueryManager.clear();
  void clearUserDocQueryCacheKey(String? uniqueKey) =>
      _userDocQueryManager.clearRequest(uniqueKey);
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
