import 'package:event_ticketing_system/apis/ets.dart';
import 'package:event_ticketing_system/pages/account_page.dart';
import 'package:event_ticketing_system/pages/analytics_page.dart';
import 'package:event_ticketing_system/pages/create_event_page.dart';
import 'package:event_ticketing_system/pages/created_events_page.dart';
import 'package:event_ticketing_system/pages/edit_event_page.dart';
import 'package:event_ticketing_system/pages/event_details_page.dart';
import 'package:event_ticketing_system/pages/joined_events_page.dart';
import 'package:event_ticketing_system/pages/login_page.dart';
import 'package:event_ticketing_system/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'apis/database.dart';
import 'apis/translations.dart';
import 'blocs/theme.dart';
import 'constants/route_names.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'widgets/app_route_observer.dart';
import './apis/ets.dart' show endpoint;

void main() async {
  await Hive.initFlutter();
  await Hive.openBox(configBoxName);
  await Hive.openBox(userBoxName);

  print('App starting using endpoint\n$endpoint');

  Map<String, String> userCredentials = FeliStorageAPI.getUserCredentials();
  if (userCredentials != null) {
    if ((userCredentials['username'] != null) &&
        (userCredentials['password'] != null)) {
      appUser.username = userCredentials['username'];
      appUser.password = userCredentials['password'];
      await appUser.login();
    }
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeliThemeChanger>(
      create: (_) => FeliThemeChanger(),
      child: MaterialAppWithTheme(),
    );

    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        pageTransitionsTheme: PageTransitionsTheme(
// makes all platforms that can run Flutter apps display routes without any animation
          builders: Map<TargetPlatform,
                  _InanimatePageTransitionsBuilder>.fromIterable(
              TargetPlatform.values.toList(),
              key: (dynamic k) => k,
              value: (dynamic _) => const _InanimatePageTransitionsBuilder()),
        ),
      ),
      initialRoute: RouteNames.home,
    );
  }
}

class MaterialAppWithTheme extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final feliTheme = Provider.of<FeliThemeChanger>(context);
    return MaterialApp(
      theme: feliTheme.getTheme('light').copyWith(
            pageTransitionsTheme: customPageTransitionTheme,
          ),
      darkTheme: feliTheme.getTheme('dark').copyWith(
            pageTransitionsTheme: customPageTransitionTheme,
          ),
      title: Translate.get('event_ticketing_system'),
      debugShowCheckedModeBanner: false,
      initialRoute: RouteNames.home,
      navigatorObservers: [AppRouteObserver()],
      routes: {
        RouteNames.home: (_) => HomePage(),
        RouteNames.settings: (_) => SettingsPage(),
        RouteNames.account: (_) => AccountPage(),
        RouteNames.login: (_) => LoginPage(),
        RouteNames.register: (_) => RegisterPage(),
        RouteNames.joinedEvents: (_) => JoinedEventsPage(),
        RouteNames.createdEvents: (_) => CreatedEventsPage(),
        RouteNames.createEvent: (_) => CreateEventPage(),
        RouteNames.analytics: (_) => AnalyticsPage(),
      },
      onGenerateRoute: (RouteSettings routeSettings) {
        if (routeSettings.name.startsWith(RouteNames.eventDetails)) {
          String eventId = routeSettings.name.split('/')[2];
          if (eventId != null && eventId != '')
            return MaterialPageRoute(builder: (_) => EventDetailsPage(eventId));
        }

        if (routeSettings.name.startsWith(RouteNames.editEvent)) {
          String eventId = routeSettings.name.split('/')[2];
          if (eventId != null && eventId != '')
            return MaterialPageRoute(builder: (_) => EditEventPage(eventId));
        }

        return MaterialPageRoute(builder: (_) => HomePage());
      },
    );
  }
}

PageTransitionsTheme customPageTransitionTheme = PageTransitionsTheme(
  builders: Map<TargetPlatform, _InanimatePageTransitionsBuilder>.fromIterable(
      TargetPlatform.values.toList(),
      key: (dynamic k) => k,
      value: (dynamic _) => const _InanimatePageTransitionsBuilder()),
);

/// This class is used to build page transitions that don't have any animation
class _InanimatePageTransitionsBuilder extends PageTransitionsBuilder {
  const _InanimatePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return child;
  }
}
