import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

DateTime _asDate(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
int _num(Object? v, [int fallback=1]) => v is num ? v.toInt() : fallback;

class LItem {
  final String id, name, category, icon;
  final int quantity;
  final String? qrCode, photoUrl;
  const LItem(this.id,this.name,this.category,this.icon,this.quantity,{this.qrCode,this.photoUrl});
  bool get hasQr => qrCode != null && qrCode!.isNotEmpty;
  factory LItem.read(DocumentSnapshot<Map<String,dynamic>> d) {
    final a=d.data()??{};
    return LItem(d.id,(a['name']??'').toString(),(a['category']??'Other').toString(),
      (a['icon']??'inventory').toString(),_num(a['quantity']),qrCode:a['qrCode'] as String?,photoUrl:a['photoUrl'] as String?);
  }
  Map<String,dynamic> get snapshot=>{'itemId':id,'itemName':name,'category':category,'icon':icon,
    'quantity':quantity,'qrCode':qrCode,'photoUrl':photoUrl,'addedDuringActivity':false,'createdAt':Timestamp.now()};
}
class LList {
  final String id,name,icon;
  const LList(this.id,this.name,this.icon);
  factory LList.read(DocumentSnapshot<Map<String,dynamic>> d) {
    final a=d.data()??{};return LList(d.id,(a['name']??'Untitled').toString(),(a['icon']??'list').toString());
  }
}
class LActivity {
  final String id,name,type,listId,status;
  final DateTime startAt,endAt;
  final bool reminderEnabled;
  final int reminderMinutes;
  const LActivity(this.id,this.name,this.type,this.listId,this.status,this.startAt,this.endAt,
    this.reminderEnabled,this.reminderMinutes);
  factory LActivity.read(DocumentSnapshot<Map<String,dynamic>> d) {
    final a=d.data()??{};
    return LActivity(d.id,(a['name']??'Activity').toString(),(a['type']??'Other').toString(),
      (a['listId']??'').toString(),(a['status']??'UPCOMING').toString(),_asDate(a['startAt']),
      _asDate(a['endAt']),a['reminderEnabled']==true,_num(a['reminderMinutes'],30));
  }
}
class LActivityItem {
  final String id,itemId,name,category,icon;
  final int quantity;
  final String? qrCode;
  final bool addedDuringActivity;
  const LActivityItem(this.id,this.itemId,this.name,this.category,this.icon,this.quantity,
    this.qrCode,this.addedDuringActivity);
  factory LActivityItem.read(DocumentSnapshot<Map<String,dynamic>> d) {
    final a=d.data()??{};
    return LActivityItem(d.id,(a['itemId']??d.id).toString(),(a['itemName']??'Item').toString(),
      (a['category']??'Other').toString(),(a['icon']??'inventory').toString(),
      _num(a['quantity']),a['qrCode'] as String?,a['addedDuringActivity']==true);
  }
}
class LCheckResult {
  final String status;
  final String? method;
  const LCheckResult(this.status,this.method);
}
class LCheckHistory {
  final Map<String,LCheckResult> before,returned;
  const LCheckHistory(this.before,this.returned);
}

class LRepo {
  final String uid;
  final FirebaseFirestore firestore;
  LRepo(this.uid):firestore=FirebaseFirestore.instance;
  static LRepo current()=>LRepo(FirebaseAuth.instance.currentUser!.uid);
  CollectionReference<Map<String,dynamic>> get items=>firestore.collection('users').doc(uid).collection('items');
  CollectionReference<Map<String,dynamic>> get lists=>firestore.collection('users').doc(uid).collection('lists');
  CollectionReference<Map<String,dynamic>> get activities=>firestore.collection('users').doc(uid).collection('activities');
  CollectionReference<Map<String,dynamic>> members(String lid)=>lists.doc(lid).collection('items');
  CollectionReference<Map<String,dynamic>> entries(String aid)=>activities.doc(aid).collection('items');
  Stream<List<LItem>> watchItems()=>items.snapshots().map((q)=>q.docs.map(LItem.read).toList()..sort((a,b)=>a.name.compareTo(b.name)));
  Stream<List<LList>> watchLists()=>lists.snapshots().map((q)=>q.docs.map(LList.read).toList()..sort((a,b)=>a.name.compareTo(b.name)));
  Stream<List<LActivity>> watchActivities()=>activities.snapshots().map((q)=>q.docs.map(LActivity.read).toList()..sort((a,b)=>a.startAt.compareTo(b.startAt)));
  Stream<List<LActivityItem>> watchEntries(String aid)=>entries(aid).snapshots().map((q)=>q.docs.map(LActivityItem.read).toList()..sort((a,b)=>a.name.compareTo(b.name)));
  Stream<Set<String>> watchMembers(String lid)=>members(lid).snapshots().map((q)=>q.docs.map((d)=>d.id).toSet());
  Future<LItem?> getItem(String id)async{final d=await items.doc(id).get();return d.exists?LItem.read(d):null;}
  Future<LItem?> getItemByQr(String code)async{
    final q=await items.where('qrCode',isEqualTo:code).limit(1).get();
    return q.docs.isEmpty?null:LItem.read(q.docs.first);
  }
  Future<String> saveItem({String? id,required String name,required String category,required int quantity,bool makeQr=false})async{
    if(name.trim().isEmpty)throw StateError('Enter an item name.');
    final ref=id==null?items.doc():items.doc(id),old=id==null?null:await ref.get();
    final previous=old?.data(),qr=(previous?['qrCode'] as String?)??(makeQr?'lakwatsa:item:'+const Uuid().v4():null);
    await ref.set({'name':name.trim(),'category':category,'icon':category.toLowerCase(),
      'quantity':quantity,'photoUrl':previous?['photoUrl'],'qrCode':qr,
      if(old==null||!old.exists)'createdAt':Timestamp.now(),'updatedAt':Timestamp.now()},SetOptions(merge:true));
    return ref.id;
  }
  Future<void> makeQr(String id)async{
    final ref=items.doc(id),old=await ref.get();
    if(!old.exists)throw StateError('Item does not exist.');
    if((old.data()?['qrCode'] as String?)?.isNotEmpty==true)return;
    await ref.update({'qrCode':'lakwatsa:item:'+const Uuid().v4(),'updatedAt':Timestamp.now()});
  }
  Future<List<LList>> listsUsing(String iid)async{
    final all=await lists.get(),output=<LList>[];
    for(final d in all.docs){if((await members(d.id).doc(iid).get()).exists)output.add(LList.read(d));}
    return output;
  }
  Future<void> deleteItem(String iid)async{
    final used=await listsUsing(iid);
    if(used.isNotEmpty)throw StateError('Remove item from these lists first: '+used.map((e)=>e.name).join(', '));
    await items.doc(iid).delete();
  }
  Future<String> createList(String name)async{
    if(name.trim().isEmpty)throw StateError('Enter a list name.');
    final ref=lists.doc();await ref.set({'name':name.trim(),'icon':'list','createdAt':Timestamp.now(),'updatedAt':Timestamp.now()});
    return ref.id;
  }
  Future<void> setMember(String lid,String iid,bool included)async{
    if(included)await members(lid).doc(iid).set({'itemId':iid,'addedAt':Timestamp.now()});
    else await members(lid).doc(iid).delete();
    await lists.doc(lid).update({'updatedAt':Timestamp.now()});
  }
  Future<List<LItem>> getListItems(String lid)async{
    final snap=await members(lid).get(),out=<LItem>[];
    for(final row in snap.docs){final it=await getItem(row.id);if(it!=null)out.add(it);}
    return out;
  }
  Future<void> deleteList(String lid)async{
    final all=await members(lid).get(),batch=firestore.batch();
    for(final doc in all.docs)batch.delete(doc.reference);
    batch.delete(lists.doc(lid));await batch.commit();
  }
  Future<String> createActivity({required String name,required String type,required String lid,
    required DateTime start,required DateTime end,required bool reminderEnabled,required int reminderMinutes})async{
    if(name.trim().isEmpty)throw StateError('Enter an Activity name.');
    if(!end.isAfter(start))throw StateError('End time must be after start time.');
    final selected=await getListItems(lid);
    if(selected.isEmpty)throw StateError('Choose a List containing at least one Item.');
    final doc=activities.doc(),batch=firestore.batch();
    batch.set(doc,{'name':name.trim(),'type':type,'listId':lid,
      'activityDate':Timestamp.fromDate(DateTime(start.year,start.month,start.day)),
      'startAt':Timestamp.fromDate(start),'endAt':Timestamp.fromDate(end),
      'reminderEnabled':reminderEnabled,'reminderMinutes':reminderMinutes,
      'status':'UPCOMING','createdAt':Timestamp.now(),'updatedAt':Timestamp.now()});
    for(final it in selected)batch.set(entries(doc.id).doc(it.id),it.snapshot);
    await batch.commit();return doc.id;
  }
  Future<LActivityItem> addToActivity(String aid,LItem item)async{
    final ref=entries(aid).doc(item.id),existing=await ref.get();
    if(existing.exists)return LActivityItem.read(existing);
    await ref.set({...item.snapshot,'addedDuringActivity':true});
    return LActivityItem.read(await ref.get());
  }
  Future<void> finishCheck(String aid,String type,List<LActivityItem> current,Map<String,String> found,DateTime startedAt)async{
    final parent=activities.doc(aid),check=parent.collection('checks').doc(),batch=firestore.batch();
    final now=Timestamp.now();
    batch.set(check,{'type':type,'startedAt':Timestamp.fromDate(startedAt),'completedAt':now,'status':'COMPLETED'});
    for(final it in current){
      final method=found[it.id];
      batch.set(check.collection('items').doc(it.id),{'activityItemId':it.id,
        'status':method==null?'NOT_FOUND':'FOUND','method':method,'checkedAt':method==null?null:now});
    }
    batch.update(parent,{'status':type=='BEFORE_ACTIVITY'?'ACTIVE':'COMPLETED','updatedAt':now});
    await batch.commit();
  }
  Future<LCheckHistory> history(String aid)async{
    final checks=await activities.doc(aid).collection('checks').get();
    final before=<String,LCheckResult>{},back=<String,LCheckResult>{};
    final ordered=checks.docs.toList()..sort((a,b)=>_asDate(a.data()['completedAt']).compareTo(_asDate(b.data()['completedAt'])));
    for(final check in ordered){
      final dest=check.data()['type']=='RETURN'?back:before;
      final values=await check.reference.collection('items').get();
      for(final row in values.docs)dest[row.id]=LCheckResult(
        (row.data()['status']??'NOT_FOUND').toString(),row.data()['method'] as String?);
    }
    return LCheckHistory(before,back);
  }
}
