// The VM side of fake_recognizer_web.dart. The VM has no page, so there is nothing to install.
// The tests that use the fake recognizer run only in Chrome (`skip: !kIsWeb`).

void installFakeRecognizer(String name,
    {String? answer, bool reject = false}) {}

void removeFakeRecognizer(String name) {}

void installFakeNavigator(String name, {required bool getUserMedia}) {}

void removeFakeNavigator(String name) {}
