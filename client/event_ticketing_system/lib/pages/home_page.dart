import 'package:event_ticketing_system/apis/ets.dart';
import 'package:event_ticketing_system/blocs/theme.dart';
import 'package:event_ticketing_system/constants/app_info.dart';
import 'package:event_ticketing_system/constants/route_names.dart';
import 'package:event_ticketing_system/misc/launch_url.dart';
import 'package:event_ticketing_system/misc/search_delegate.dart';
import 'package:event_ticketing_system/misc/show_address_selector_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../apis/database.dart';
import '../apis/translations.dart';
import '../constants/page_titles.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Widget> eventWidgets = [];
  bool loading = true;
  List rawEvents = [];

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  getData() async {
    List events = await EtsAPI.getEvents();
    if (events != null) {
      rawEvents = events;
    }
    setState(() {
      loading = false;
    });
    for (var e in events) {
      FeliEvent event = FeliEvent.fromJson(e);
      setState(() {
        eventWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Card(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // backgroundColor: Colors.black,
                // trailing: Text(
                //   '${event.participants.length}/${event.participantLimit} ${Translate.get('joined')} ${event.waitingList.length} ${Translate.get('queued')}',
                //   style: Theme.of(context)
                //       .textTheme
                //       .subtitle2
                //       .copyWith(fontSize: 12.0),
                // ),
                title: Text('${event.name}'),
                subtitle: Text(
                  '${event.participants.length}/${event.participantLimit} ${Translate.get('joined')} ${event.waitingList.length} ${Translate.get('queued')}',
                ),
                initiallyExpanded: false,
                children: [
                  ListTile(
                    title: Text(Translate.get('name')),
                    subtitle: Text('${event.name}'),
                  ),
                  ListTile(
                    title: Text(Translate.get('description')),
                    subtitle: Text('${event.description}'),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('organiser')),
                    subtitle: Text('${event.organiser}'),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('start_date_time')),
                    subtitle: Text(DateFormat().format(
                        DateTime.fromMillisecondsSinceEpoch(event.startTime))),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('end_date_time')),
                    subtitle: Text(DateFormat().format(
                        DateTime.fromMillisecondsSinceEpoch(event.endTime))),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('venue')),
                    subtitle: Text('${event.venue}'),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('theme')),
                    subtitle: Text('${event.theme}'),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('participant_limit')),
                    subtitle: Text('${event.participantLimit}'),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(Translate.get('id')),
                    subtitle: Text('${event.id}'),
                  ),
                  RaisedButton(
                    child: Text(Translate.get('view_details')),
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(RouteNames.eventDetails + '/${event.id}');
                    },
                  )
                ],
              ),
            ),
          ),
        ));
      });
    }
  }

  @override
  void initState() {
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool displayMobileLayout = deviceWidth < 600;

    return AppScaffold(
      loading: loading,
      pageTitle: PageTitles.home,
      actions: [
        IconButton(
          tooltip: Translate.get('search'),
          icon: Icon(Icons.search),
          onPressed: !loading
              ? () {
                  showSearch(
                    context: context,
                    delegate: EventSearch(rawEvents),
                  );
                }
              : null,
        ),
      ],
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        Translate.get('events'),
                        style: Theme.of(context).textTheme.headline5,
                      ),
                      if (loading) Text(Translate.get('loading')),
                      ...eventWidgets,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
