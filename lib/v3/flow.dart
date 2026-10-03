import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'repository.dart';
import 'ui.dart';
import 'scanner.dart';

class ListsTab extends StatelessWidget {
 final LRepo db;const ListsTab(this.db,{super.key});
 @override Widget build(BuildContext context)=>Column(children:[
 Padding(padding:const EdgeInsets.all(20),child:Row(children:[
 Expanded(child:Text('Lists',style:AppTextStyles.heading)),
 IconButton.filled(onPressed:()async{
 final input=TextEditingController();
 final name=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Create List'),
 content:TextField(controller:input,decoration:field('List name')),
 actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),
 TextButton(onPressed:()=>Navigator.pop(d,input.text.trim()),child:const Text('Create'))]));
 input.dispose();
 if(name!=null&&name.isNotEmpty){try{await db.createList(name);}catch(e){notice(context,e);}}
 },icon:const Icon(Icons.add))])),
 Expanded(child:StreamBuilder<List<LList>>(stream:db.watchLists(),builder:(c,s){
 if(s.hasError)return Center(child:Text(s.error.toString()));
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 if(s.data!.isEmpty)return const Center(child:Text('No Lists yet. Tap +.'));
 return ListView.builder(padding:const EdgeInsets.symmetric(horizontal:20),itemCount:s.data!.length,
 itemBuilder:(c,i){final l=s.data![i];return Padding(padding:const EdgeInsets.only(bottom:12),
 child:BorderedCard(background:AppColors.card,
 onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ListDetails(db,l))),
 child:Row(children:[const Icon(Icons.list_alt,size:35),const SizedBox(width:14),
 Expanded(child:Text(l.name,style:AppTextStyles.heading)),const Icon(Icons.chevron_right)])));});})),
 ]);}
class ListDetails extends StatelessWidget {
 final LRepo db;final LList list;const ListDetails(this.db,this.list,{super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(list.name)),
 body:StreamBuilder<Set<String>>(stream:db.watchMembers(list.id),builder:(c,m)=>Column(children:[
 Padding(padding:const EdgeInsets.all(20),child:BorderedCard(background:AppColors.card,
 child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(list.name,style:AppTextStyles.heading),
 Text((m.data?.length??0).toString()+' Items · Reusable List',style:AppTextStyles.body)]))),
 Expanded(child:StreamBuilder<List<LItem>>(stream:db.watchItems(),builder:(c,s){
 if(!m.hasData||!s.hasData)return const Center(child:CircularProgressIndicator());
 final selected=s.data!.where((i)=>m.data!.contains(i.id)).toList();
 if(selected.isEmpty)return const Center(child:Text('No Items. Use Add Items below.'));
 return ListView.builder(padding:const EdgeInsets.symmetric(horizontal:20),itemCount:selected.length,
 itemBuilder:(c,i){final it=selected[i];return Padding(padding:const EdgeInsets.only(bottom:11),
 child:itemCard(it.name,it.category,it.quantity,qr:it.hasQr,
 action:IconButton(icon:const Icon(Icons.remove_circle_outline),
 onPressed:()=>db.setMember(list.id,it.id,false))));});})),
 Padding(padding:const EdgeInsets.all(20),child:Column(children:[
 ActionButton('+ Add Items',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AddListItems(db,list.id))),primary:false),
 vgap(12),ActionButton('Delete List',()async{
 try{await db.deleteList(list.id);if(context.mounted)Navigator.pop(context);}catch(e){notice(context,e);}
 },primary:false)]))
 ])));
}
class AddListItems extends StatelessWidget{
 final LRepo db;final String lid;const AddListItems(this.db,this.lid,{super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Add Items')),
 body:StreamBuilder<Set<String>>(stream:db.watchMembers(lid),builder:(c,m)=>
 StreamBuilder<List<LItem>>(stream:db.watchItems(),builder:(c,s){
 if(!s.hasData||!m.hasData)return const Center(child:CircularProgressIndicator());
 return ListView(padding:const EdgeInsets.all(20),children:[
 for(final it in s.data!)Padding(padding:const EdgeInsets.only(bottom:11),
 child:itemCard(it.name,it.category,it.quantity,qr:it.hasQr,
 action:Checkbox(value:m.data!.contains(it.id),onChanged:(v)=>db.setMember(lid,it.id,v??false)))),
 vgap(15),ActionButton('Done',()=>Navigator.pop(context))
 ]);})));
}
class ActivitiesTab extends StatefulWidget{
 final LRepo db;const ActivitiesTab(this.db,{super.key});@override State<ActivitiesTab> createState()=>_ActivitiesTabState();
}
class _ActivitiesTabState extends State<ActivitiesTab>{
 String tab='UPCOMING';
 @override Widget build(BuildContext context)=>Column(children:[
 Padding(padding:const EdgeInsets.fromLTRB(20,17,20,10),child:Row(children:[
 Expanded(child:Text('Activities',style:AppTextStyles.heading)),
 IconButton.filled(onPressed:()=>Navigator.push(context,
 MaterialPageRoute(builder:(_)=>CreateActivity(widget.db))),icon:const Icon(Icons.add))])),
 Padding(padding:const EdgeInsets.fromLTRB(20,0,20,10),child:Row(children:[
 for(final t in ['UPCOMING','ACTIVE','COMPLETED'])Expanded(child:Padding(
 padding:const EdgeInsets.only(right:3),child:ActionButton(
 t=='COMPLETED'?'History':t[0]+t.substring(1).toLowerCase(),
 ()=>setState(()=>tab=t),primary:tab==t)))])),
 Expanded(child:StreamBuilder<List<LActivity>>(stream:widget.db.watchActivities(),builder:(c,s){
 if(s.hasError)return Center(child:Text(s.error.toString()));
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final found=s.data!.where((a)=>a.status==tab).toList();
 if(found.isEmpty)return Center(child:Text(tab=='UPCOMING'?'No upcoming Activities.':'No Activities in this section.'));
 return ListView.builder(padding:const EdgeInsets.fromLTRB(20,10,20,25),
 itemCount:found.length,itemBuilder:(c,i){final a=found[i];
 return Padding(padding:const EdgeInsets.only(bottom:13),child:BorderedCard(
 onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ActivityDetails(widget.db,a))),
 child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(a.type.toUpperCase(),style:AppTextStyles.pixelDark),vgap(9),
 Text(a.name,style:AppTextStyles.heading.copyWith(fontSize:18)),
 Text('Start: '+a.startAt.toString().split('.')[0],style:AppTextStyles.body),
 Text('End: '+a.endAt.toString().split('.')[0],style:AppTextStyles.body),
 vgap(9),Text(a.status,style:AppTextStyles.pixelDark)
 ])));});}))
 ]);}
class CreateActivity extends StatefulWidget{
 final LRepo db;const CreateActivity(this.db,{super.key});@override State<CreateActivity> createState()=>_CreateActivityState();
}
class _CreateActivityState extends State<CreateActivity>{
 final name=TextEditingController();String type='Trip';String? lid;
 DateTime date=DateTime.now();TimeOfDay start=const TimeOfDay(hour:8,minute:0);
 TimeOfDay end=const TimeOfDay(hour:17,minute:0);
 bool reminder=true,busy=false;int minutes=30;
 @override void dispose(){name.dispose();super.dispose();}
 Future<void> save()async{
 if(lid==null){notice(context,'Choose a Packing List.');return;}
 final from=DateTime(date.year,date.month,date.day,start.hour,start.minute);
 final to=DateTime(date.year,date.month,date.day,end.hour,end.minute);
 setState(()=>busy=true);
 try{await widget.db.createActivity(name:name.text,type:type,lid:lid!,start:from,end:to,
 reminderEnabled:reminder,reminderMinutes:minutes);if(mounted)Navigator.pop(context);}
 catch(e){notice(context,e);}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Create Activity')),
 body:ListView(padding:const EdgeInsets.all(20),children:[
 Text('ACTIVITY NAME',style:AppTextStyles.pixel),vgap(7),
 TextField(controller:name,decoration:field('Activity name')),vgap(18),
 Text('TYPE',style:AppTextStyles.pixel),vgap(7),
 DropdownButtonFormField<String>(value:type,decoration:field('Type'),
 items:[for(final t in activityTypes)DropdownMenuItem(value:t,child:Text(t))],
 onChanged:(v)=>setState(()=>type=v??type)),vgap(18),
 Text('PACKING LIST',style:AppTextStyles.pixel),vgap(7),
 StreamBuilder<List<LList>>(stream:widget.db.watchLists(),builder:(c,s){
 final lists=s.data??[];
 return DropdownButtonFormField<String>(value:lists.any((l)=>l.id==lid)?lid:null,
 decoration:field('Choose a List'),items:[for(final l in lists)DropdownMenuItem(value:l.id,child:Text(l.name))],
 onChanged:(v)=>setState(()=>lid=v));}),
 if(lid!=null)FutureBuilder<List<LItem>>(future:widget.db.getListItems(lid!),builder:(c,s){
 if(!s.hasData)return const LinearProgressIndicator();
 return Padding(padding:const EdgeInsets.symmetric(vertical:12),
 child:BorderedCard(background:AppColors.card,child:Column(
 crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('Items in selected List ('+s.data!.length.toString()+')',style:AppTextStyles.bodyBold),
 for(final it in s.data!)Padding(padding:const EdgeInsets.only(top:7),
 child:Text(it.name+' · Qty '+it.quantity.toString(),style:AppTextStyles.body))])));}),
 vgap(15),ActionButton('Date: '+date.day.toString()+'/'+date.month.toString()+'/'+date.year.toString(),()async{
 final d=await showDatePicker(context:context,initialDate:date,
 firstDate:DateTime(2020),lastDate:DateTime(2100));
 if(d!=null)setState(()=>date=d);},primary:false),
 vgap(12),Row(children:[
 Expanded(child:ActionButton('Start '+start.format(context),()async{
 final v=await showTimePicker(context:context,initialTime:start);
 if(v!=null)setState(()=>start=v);},primary:false)),const SizedBox(width:10),
 Expanded(child:ActionButton('End '+end.format(context),()async{
 final v=await showTimePicker(context:context,initialTime:end);
 if(v!=null)setState(()=>end=v);},primary:false))]),
 vgap(12),SwitchListTile(title:const Text('Return reminder preference'),value:reminder,
 onChanged:(v)=>setState(()=>reminder=v)),
 if(reminder)DropdownButtonFormField<int>(value:minutes,decoration:field('Minutes before end'),
 items:const [DropdownMenuItem(value:15,child:Text('15 min')),
 DropdownMenuItem(value:30,child:Text('30 min')),DropdownMenuItem(value:60,child:Text('1 hour'))],
 onChanged:(v)=>setState(()=>minutes=v??minutes)),
 vgap(20),ActionButton(busy?'Saving...':'Create Activity',busy?null:save)
 ]));
}
class ActivityDetails extends StatelessWidget{
 final LRepo db;final LActivity activity;const ActivityDetails(this.db,this.activity,{super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(activity.name)),
 body:StreamBuilder<List<LActivityItem>>(stream:db.watchEntries(activity.id),builder:(c,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 return ListView(padding:const EdgeInsets.all(20),children:[
 BorderedCard(background:AppColors.card,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(activity.name,style:AppTextStyles.heading),vgap(8),
 Text(activity.type+' · '+activity.status,style:AppTextStyles.bodyBold),
 Text('Start: '+activity.startAt.toString().split('.')[0],style:AppTextStyles.body),
 Text('End: '+activity.endAt.toString().split('.')[0],style:AppTextStyles.body)])),vgap(20),
 Text('ITEMS · '+s.data!.length.toString(),style:AppTextStyles.pixel),vgap(12),
 for(final it in s.data!)Padding(padding:const EdgeInsets.only(bottom:10),
 child:itemCard(it.name,it.category,it.quantity,qr:it.qrCode!=null)),
 vgap(18),ActionButton(activity.status=='UPCOMING'?'Check Items Before Leaving':
 activity.status=='ACTIVE'?'Check Items Before Going Home':'View Check Results',()async{
 await Navigator.push(context,MaterialPageRoute(builder:(_)=>
 activity.status=='COMPLETED'?CheckHistoryScreen(db,activity):CheckScreen(db,activity)));
 if(context.mounted)Navigator.pop(context);
 })
 ]);}));
}
class CheckScreen extends StatefulWidget{
 final LRepo db;final LActivity activity;const CheckScreen(this.db,this.activity,{super.key});
 @override State<CheckScreen> createState()=>_CheckScreenState();
}
class _CheckScreenState extends State<CheckScreen>{
 final found=<String,String>{};final DateTime started=DateTime.now();bool saving=false;
 bool get returning=>widget.activity.status=='ACTIVE';
 Future<void> scan(List<LActivityItem> entries)async{
 final received=await Navigator.push<Map<String,String>>(context,MaterialPageRoute(
 builder:(_)=>QrScanScreen(widget.db,widget.activity.id,entries,found)));
 if(mounted&&received!=null)setState((){found..clear()..addAll(received);});
 }
 Future<void> finish(List<LActivityItem> items)async{
 final unchecked=items.length-found.length;
 final confirmed=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
 title:Text(unchecked==0?'All Items Checked':'Finish Checking?'),
 content:Text(unchecked==0?'All Items are confirmed. Finish?':
 unchecked.toString()+' Item(s) will be recorded as NOT_FOUND if you finish now.'),
 actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Keep Checking')),
 TextButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Finish Anyway'))]));
 if(confirmed!=true)return;
 setState(()=>saving=true);
 try{await widget.db.finishCheck(widget.activity.id,returning?'RETURN':'BEFORE_ACTIVITY',items,found,started);
 if(mounted)Navigator.pop(context,true);}
 catch(e){notice(context,e);}finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(returning?'Return Check':'Before Activity Check')),
 body:StreamBuilder<List<LActivityItem>>(stream:widget.db.watchEntries(widget.activity.id),builder:(c,s){
 if(s.hasError)return Center(child:Text(s.error.toString()));
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final items=s.data!;
 return Column(children:[
 Padding(padding:const EdgeInsets.all(20),child:BorderedCard(background:AppColors.card,
 child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(returning?'CHECK BELONGINGS':'CHECK ITEMS',style:AppTextStyles.pixelDark),vgap(),
 Text(found.length.toString()+' / '+items.length.toString()+' ITEMS CHECKED',style:AppTextStyles.heading),
 vgap(10),LinearProgressIndicator(value:items.isEmpty?0:found.length/items.length,
 backgroundColor:AppColors.background,color:AppColors.green)]))),
 Expanded(child:ListView.builder(padding:const EdgeInsets.symmetric(horizontal:20),itemCount:items.length,itemBuilder:(c,i){
 final it=items[i],checked=found.containsKey(it.id);
 return Padding(padding:const EdgeInsets.only(bottom:12),child:itemCard(it.name,it.category,it.quantity,
 qr:it.qrCode!=null,action:Icon(checked?Icons.check_circle:Icons.circle_outlined,
 color:checked?AppColors.green:AppColors.ink),
 onTap:()=>setState((){if(checked)found.remove(it.id);else found[it.id]='MANUAL';})));})),
 Padding(padding:const EdgeInsets.all(20),child:Column(children:[
 ActionButton('Scan QR Codes',saving?null:()=>scan(items),primary:false),vgap(10),
 ActionButton(saving?'Saving...':returning?'Finish Activity':'Finish Checking',
 saving?null:()=>finish(items))]))
 ]);}));
}
class CheckHistoryScreen extends StatelessWidget{
 final LRepo db;final LActivity activity;const CheckHistoryScreen(this.db,this.activity,{super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Check Results')),
 body:FutureBuilder<LCheckHistory>(future:db.history(activity.id),builder:(c,s){
 if(s.hasError)return Center(child:Text(s.error.toString()));
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 return StreamBuilder<List<LActivityItem>>(stream:db.watchEntries(activity.id),builder:(c,items){
 if(!items.hasData)return const Center(child:CircularProgressIndicator());
 return ListView(padding:const EdgeInsets.all(20),children:[
 BorderedCard(background:AppColors.card,child:Text(activity.name,style:AppTextStyles.heading)),vgap(17),
 Row(children:[const Expanded(flex:2,child:Text('ITEM')),
 Expanded(child:Text('BEFORE',style:AppTextStyles.pixelDark)),
 Expanded(child:Text('RETURN',style:AppTextStyles.pixelDark))]),vgap(12),
 for(final it in items.data!)Padding(padding:const EdgeInsets.only(bottom:12),
 child:BorderedCard(child:Row(children:[
 Expanded(flex:2,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(it.name,style:AppTextStyles.bodyBold),
 if(it.addedDuringActivity)Text('Added during Activity',style:AppTextStyles.body)])),
 Expanded(child:status(s.data!.before[it.id])),
 Expanded(child:status(s.data!.returned[it.id]))
 ]))),
 BorderedCard(background:AppColors.card,child:Text('MANUAL: tapped on the checklist · QR: scanned the Item QR',style:AppTextStyles.body))
 ]);});}));
 Widget status(LCheckResult? r)=>Column(children:[
 Text(r==null?'—':r.status=='NOT_FOUND'?'MISSING':r.status,style:AppTextStyles.bodyBold.copyWith(fontSize:9,
 color:r?.status=='FOUND'?AppColors.green:AppColors.ink)),
 Text(r?.method??'',style:AppTextStyles.body.copyWith(fontSize:9))]);
}
