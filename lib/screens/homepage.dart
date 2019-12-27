import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:sies_library/components/BookListItem.dart';
import 'package:sies_library/models/book.dart';
import 'package:sies_library/models/sort_state.dart';
import 'package:sies_library/services/library_service.dart';
import 'package:sies_library/util/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List bookList = [];
  bool isLoading;
  int _pageNumber;
  ScrollController sc;
  String searchType;

  _launchURL() async {
    const url = 'https://github.com/kriticalflare/SIES-Library';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void getResults(int pageNumber) async {
    LibraryService libraryService = LibraryService();
    // '' is passed to sort type for unsorted results
    List resultList = await libraryService.getSearchResult(
        SearchType.TITLE, '', '20', '$pageNumber', '');
    bookList.addAll(resultList);
    isLoading = false;
    setState(() {});
//    for (Results book in bookList) {
//      print('id :${book.sId} ${book.title}');
//    }
  }

  @override
  void initState() {
    super.initState();
    isLoading = true;
    _pageNumber = 0;
    getResults(++_pageNumber);
    searchType = SearchType.TITLE;
  }

  Widget _buildProgressIndicator() {
    return new Padding(
      padding: const EdgeInsets.all(8.0),
      child: new Center(
        child: new CircularProgressIndicator(),
      ),
    );
  }

  Widget _createListView() {
    sc = ScrollController();
    sc.addListener(() {
      if (sc.position.maxScrollExtent == sc.position.pixels) {
        if (isLoading == false) {
          _pageNumber = _pageNumber + 1;
          getResults(_pageNumber);
          // Perform event when user reach at the end of list (e.g. do Api call)
        }
      }
    });
    return ListView.builder(
        controller: sc,
        itemCount: bookList.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == bookList.length) {
            return ListTile(
              title: _buildProgressIndicator(),
            );
          } else {
            return BookListItem(
              book: bookList[index],
              index: index,
              pop: false,
            );
          }
        });
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: (){
            showAboutDialog(context: context ,
                applicationName: 'Sies Library' ,
                applicationVersion: '1.0.0' ,
                applicationIcon: Image.asset('assets/appicon.png'),
                applicationLegalese: 'App by @kriticalflare  \n\nUses icons from icons8.com',
                children:[
                  Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: Center(
                      child: GestureDetector(
                          onTap: (){
                            _launchURL();
                          },
                          child: Image.asset('assets/github.png' , height: 70, width: 70,)
                      ),
                    ),
                  )
                ] );
          },
          child: Text(
            'Sies Library',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
            child: bookList.isEmpty
                ? Center(child: CircularProgressIndicator())
                : _createListView()),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(
          Icons.search,
        ),
        onPressed: () {
//          getResults(_pageNumber);
          showSearch(context: context, delegate: BookSearch());
        },
      ),
    );
  }
}

class BookSearch extends SearchDelegate {

  var sortBox;
  SortState sortState;

  String _searchType;
  String _sortType;
//  = SortType.QUANTITY_DESCENDING;

  BookSearch(){
    _handleSortState();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(
          Icons.clear,
        ),
        onPressed: () {
          query = "";
        },
      ),
      IconButton(
        icon: Icon(Icons.tune),
        onPressed: () {
          _showDialog(context);
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // TODO: implement buildResults
    return FutureBuilder(
      future: searchBooks(query, _searchType),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        } else if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done) {
          return Center(
            child: Container(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "We couldn't find what you were looking for.",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        } else {
          List<Results> results = snapshot.data;
          if (results.isEmpty) {
            return Center(
              child: Container(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    "We couldn't find what you were looking for.",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            );
          } else {
            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                return BookListItem(book: results[index],pop: true,);
              },
            );
          }
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO: implement buildSuggestions
    return Center(
      child: Container(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Tip: Tap the icon on top right to search according to Title, Author, Publisher etc",
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  // https://github.com/flutter/flutter/issues/32180
  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context);

  Future<List<Results>> searchBooks(String query, String searchType) async {
    LibraryService libraryService = LibraryService();
    List resultList =
        await libraryService.getSearchResult(searchType, query, '25', '1', _sortType);
    return resultList;
  }

  void _handleSortState() async {
    try{
      sortBox = await Hive.openBox('sortBox');
      sortState = sortBox.getAt(0);
//      print('successfully read from hive');
    }on RangeError{
//      print('fail to read from hive');
      // first launch , user prefs not set
      sortState = SortState(searchType: SearchType.TITLE, sortType: SortType.YEAR_DESCENDING);
    } finally {
      _searchType = sortState.searchType;
      _sortType = sortState.sortType;
    }
  }

  void _showDialog(BuildContext context) {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: Text("Search Filter"),
          content: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Search by: '),
                    StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        return searchTypeDropdown(setState);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Sort by: '),
                    StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        return sortDropdown(setState);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            FlatButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  DropdownButton<String> searchTypeDropdown(StateSetter setState) {
    List<DropdownMenuItem<String>> dropDownMenuItems = [];
    List searchTypeList = [
      SearchType.TITLE,
      SearchType.AUTHOR,
      SearchType.PUBLISHER,
      SearchType.ISBN
    ];

    var searchMap = {
      SearchType.TITLE: 'Title',
      SearchType.AUTHOR: 'Author',
      SearchType.PUBLISHER: 'Publisher',
      SearchType.ISBN: 'ISBN',
    };

    for (String type in searchTypeList) {
      var newItem = DropdownMenuItem(
        child: Text(searchMap[type]),
        value: type,
      );
      dropDownMenuItems.add(newItem);
    }

    return DropdownButton<String>(
      value: _searchType,
      items: dropDownMenuItems,
      onChanged: (value) {
        setState(() {
          _searchType = value;
          sortBox.put(0, SortState(sortType: _sortType,searchType:_searchType));
        });
        //TODO: set new Search type. Provider Time ?
      },
    );
  }

  DropdownButton<String> sortDropdown(StateSetter setState) {
    List<DropdownMenuItem<String>> dropDownMenuItems = [];
    List sortTypeList = [
      SortType.QUANTITY_DESCENDING,
      SortType.QUANTITY_ASCENDING,
      SortType.YEAR_DESCENDING,
      SortType.YEAR_ASCENDING,
    ];
    var sortMap = {
      SortType.YEAR_DESCENDING : 'Newest',
      SortType.YEAR_ASCENDING : 'Oldest',
      SortType.QUANTITY_DESCENDING : 'Maximum',
      SortType.QUANTITY_ASCENDING : 'Minimum'
    };
    for (String type in sortTypeList) {
      var newItem = DropdownMenuItem(
        child: Text(sortMap[type]),
        value: type,
      );
      dropDownMenuItems.add(newItem);
    }

    return DropdownButton<String>(
      value: _sortType,
      items: dropDownMenuItems,
      onChanged: (value) {
        setState(() {
          _sortType = value;
          sortBox.put(0, SortState(sortType: _sortType,searchType:_searchType));
        });
      },
    );
  }
}
