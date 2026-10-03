import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import 'repository.dart';
import 'scanner.dart';
import 'flow.dart';

const categories = ['Electronics','Documents','Clothing','Toiletries','Other'];
const activityTypes = ['Trip','School','Work','Daily','Other'];
void notice(BuildContext c, Object? value) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(value.toString())));
}
InputDecoration field(String hint) => InputDecoration(
  hintText:hint,filled:true,fillColor:AppColors.background,
  border:OutlineInputBorder(borderSide:const BorderSide(color:AppColors.ink,width:2),borderRadius:BorderRadius.circular(4)),
  enabledBorder:OutlineInputBorder(borderSide:const BorderSide(color:AppColors.ink,width:2),borderRadius:BorderRadius.circular(4)),
  focusedBorder:OutlineInputBorder(borderSide:const BorderSide(color:AppColors.green,width:2),borderRadius:BorderRadius.circular(4)));
Widget vgap([double v=12]) => SizedBox(height:v);
class ActionButton extends StatelessWidget {
  final String title;final VoidCallback? onPressed;final bool primary;
  const ActionButton(this.title,this.onPressed,{super.key,this.primary=true});
  @override Widget build(BuildContext context)=>SizedBox(height:48,child:ElevatedButton(
    onPressed:onPressed,style:ElevatedButton.styleFrom(
      backgroundColor:primary?AppColors.ink:AppColors.card,
      foregroundColor:primary?AppColors.background:AppColors.ink,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(4),
        side:const BorderSide(color:AppColors.ink,width:2))),
    child:Text(title,style:AppTextStyles.bodyBold,textAlign:TextAlign.center)));
}
class BorderedCard extends StatelessWidget {
  final Widget child;final VoidCallback? onTap;final Color background;
  const BorderedCard({super.key,required this.child,this.onTap,this.background=AppColors.background});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(right:5,bottom:5),
    child:InkWell(onTap:onTap,child:Container(width:double.infinity,padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:background,border:Border.all(color:AppColors.ink,width:2.5),
       borderRadius:BorderRadius.circular(4),
       boxShadow:const [BoxShadow(color:AppColors.ink,offset:Offset(4,4))]),child:child)));
}
Widget itemCard(String name,String category,int quantity,{bool qr=false,Widget? action,VoidCallback? onTap})=>
  BorderedCard(onTap:onTap,child:Row(children:[
    Container(width:44,height:44,alignment:Alignment.center,
      decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(4)),
      child:Text(name.isNotEmpty?name[0].toUpperCase():'?',style:AppTextStyles.heading)),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
      children:[Text(name,style:AppTextStyles.bodyBold,maxLines:1,overflow:TextOverflow.ellipsis),
        Text(category+'  ·  Qty '+quantity.toString(),style:AppTextStyles.body)])),
    if(qr)const Icon(Icons.qr_code_2,color:AppColors.orange),
    if(action!=null)action]));
class AuthScreen extends StatefulWidget {const AuthScreen({super.key});@override State<AuthScreen> createState()=>_AuthScreenState();}
class _AuthScreenState extends State<AuthScreen> {
 final email=TextEditingController(),pass=TextEditingController();bool register=false,busy=false;
 @override void dispose(){email.dispose();pass.dispose();super.dispose();}
 Future<void> submit()async{if(email.text.trim().isEmpty||pass.text.isEmpty){notice(context,'Enter email and password.');return;}
  setState(()=>busy=true);try{if(register)await FirebaseAuth.instance.createUserWithEmailAndPassword(email:email.text.trim(),password:pass.text);
  else await FirebaseAuth.instance.signInWithEmailAndPassword(email:email.text.trim(),password:pass.text);
  }on FirebaseAuthException catch(e){notice(context,e.message??e.code);}catch(e){notice(context,e);}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(
  padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.luggage_outlined,size:78),vgap(12),
      Text('Lakwatsa',textAlign:TextAlign.center,style:AppTextStyles.heading.copyWith(fontSize:36)),
      Text('pack smart. scan easy.',textAlign:TextAlign.center,style:AppTextStyles.pixel),vgap(40),
      Text(register?'Create Account':'Sign In',style:AppTextStyles.heading),vgap(),
      TextField(controller:email,decoration:field('Email'),keyboardType:TextInputType.emailAddress),vgap(),
      TextField(controller:pass,decoration:field('Password'),obscureText:true),vgap(20),
      ActionButton(busy?'Please wait...':register?'Create Account':'Sign In',busy?null:submit),
      TextButton(onPressed:busy?null:()=>setState(()=>register=!register),
        child:Text(register?'Already registered? Sign In':'Need an account? Register'))]))))));
}
class AppShell extends StatefulWidget {const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{
 late final LRepo db;int index=0;
 @override void initState(){super.initState();db=LRepo.current();}
 @override Widget build(BuildContext context)=>Scaffold(
  body:SafeArea(child:IndexedStack(index:index,children:[
    HomeTab(db,go:(n)=>setState(()=>index=n)),ItemsTab(db),ListsTab(db),ActivitiesTab(db)])),
  bottomNavigationBar:Container(height:56,decoration:const BoxDecoration(
    border:Border(top:BorderSide(color:AppColors.ink,width:2))),child:Row(children:[
    for(var i=0;i<4;i++)Expanded(child:InkWell(onTap:()=>setState(()=>index=i),child:Column(
      mainAxisAlignment:MainAxisAlignment.center,children:[
        Text(['Home','Items','Lists','Activities'][i],style:i==index?AppTextStyles.navSelected:AppTextStyles.nav),
        vgap(5),Container(width:4,height:4,color:index==i?AppColors.ink:Colors.transparent)])))])));
}
class HomeTab extends StatelessWidget {
 final LRepo db;final ValueChanged<int> go;const HomeTab(this.db,{super.key,required this.go});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
  Row(children:[Text('Lakwatsa',style:AppTextStyles.heading),const Spacer(),
    IconButton(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout))]),
  vgap(25),Text('Your items. Always ready.',style:AppTextStyles.heading),vgap(20),
  StreamBuilder<List<LActivity>>(stream:db.watchActivities(),builder:(c,s){
    final active=(s.data??[]).where((a)=>a.status=='ACTIVE').toList();
    return BorderedCard(background:AppColors.card,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(active.isEmpty?'READY TO PACK':'ACTIVE',style:AppTextStyles.pixelDark),vgap(),
      Text(active.isEmpty?'Plan your next Activity':active.first.name,style:AppTextStyles.heading),vgap(),
      Text(active.isEmpty?'Create a List and prepare your belongings.':'Remember to check your belongings before going home.',style:AppTextStyles.body),
      vgap(18),ActionButton('Open Activities',()=>go(3))]));}),vgap(22),
  Text('Quick Actions',style:AppTextStyles.heading),vgap(12),
  Row(children:[for(var i=1;i<4;i++)Expanded(child:Padding(padding:const EdgeInsets.only(right:8),
    child:ActionButton(['','Items','Lists','Activities'][i],()=>go(i),primary:false)))]),
  vgap(25),Text('Recent Lists',style:AppTextStyles.heading),vgap(),
  StreamBuilder<List<LList>>(stream:db.watchLists(),builder:(c,s)=>Column(children:[
    for(final l in (s.data??[]).take(3))Padding(padding:const EdgeInsets.only(bottom:9),
      child:BorderedCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ListDetails(db,l))),
        child:Text(l.name,style:AppTextStyles.bodyBold)))]))
 ]);}
class ItemsTab extends StatefulWidget {final LRepo db;const ItemsTab(this.db,{super.key});@override State<ItemsTab> createState()=>_ItemsTabState();}
class _ItemsTabState extends State<ItemsTab>{
 String filter='';
 @override Widget build(BuildContext context)=>Column(children:[
  Padding(padding:const EdgeInsets.all(20),child:Row(children:[
    Expanded(child:Text('My Items',style:AppTextStyles.heading)),
    IconButton.filled(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ItemEditor(widget.db))),icon:const Icon(Icons.add))])),
  Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(decoration:field('Search items...'),
    onChanged:(v)=>setState(()=>filter=v.toLowerCase()))),
  vgap(),Expanded(child:StreamBuilder<List<LItem>>(stream:widget.db.watchItems(),builder:(c,s){
    if(s.hasError)return Center(child:Text(s.error.toString()));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final found=s.data!.where((i)=>i.name.toLowerCase().contains(filter)).toList();
    if(found.isEmpty)return const Center(child:Text('No Items yet. Tap +.'));
    return ListView.builder(padding:const EdgeInsets.fromLTRB(20,0,20,30),itemCount:found.length,itemBuilder:(c,i){
      final it=found[i];return Padding(padding:const EdgeInsets.only(bottom:10),child:itemCard(
        it.name,it.category,it.quantity,qr:it.hasQr,
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ItemEditor(widget.db,item:it)))));});}))
 ]);}
class ItemEditor extends StatefulWidget {
 final LRepo db;final LItem? item;const ItemEditor(this.db,{super.key,this.item});
 @override State<ItemEditor> createState()=>_ItemEditorState();
}
class _ItemEditorState extends State<ItemEditor>{
 late final TextEditingController name;late String category;late int qty;
 bool makeCode=false,busy=false;LItem? latest;
 @override void initState(){super.initState();latest=widget.item;name=TextEditingController(text:latest?.name??'');
  category=latest?.category??'Electronics';qty=latest?.quantity??1;}
 @override void dispose(){name.dispose();super.dispose();}
 Future<void> save()async{
  setState(()=>busy=true);
  try{await widget.db.saveItem(id:latest?.id,name:name.text,category:category,quantity:qty,makeQr:makeCode);
    if(mounted)Navigator.pop(context);}catch(e){notice(context,e);}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> remove()async{
   try{
     final used=await widget.db.listsUsing(latest!.id);
     if(!mounted)return;
     if(used.isNotEmpty){
       await showDialog<void>(context:context,builder:(d)=>AlertDialog(
         title:const Text('Cannot Delete Item'),
         content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text('Remove this Item from these Lists before deleting it:',style:AppTextStyles.body),
           for(final list in used)ListTile(title:Text(list.name),trailing:const Icon(Icons.chevron_right),
             onTap:(){
               Navigator.pop(d);
               Navigator.push(context,MaterialPageRoute(builder:(_)=>ListDetails(widget.db,list)));
             })]),
         actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('OK'))]));
       return;
     }
     final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
       title:const Text('Delete Item?'),content:Text('Delete '+latest!.name+' from My Items?'),
       actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),
         TextButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Delete'))]));
     if(ok!=true)return;
     await widget.db.deleteItem(latest!.id);
     if(mounted)Navigator.pop(context);
   }catch(e){notice(context,e);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.item==null?'Add Item':'Edit Item')),
   body:ListView(padding:const EdgeInsets.all(20),children:[
     Text('ITEM NAME',style:AppTextStyles.pixel),vgap(7),
     TextField(controller:name,decoration:field('Item name')),vgap(18),
     Text('CATEGORY',style:AppTextStyles.pixel),vgap(7),
     DropdownButtonFormField<String>(value:category,decoration:field('Category'),
       items:[for(final c in categories)DropdownMenuItem(value:c,child:Text(c))],
       onChanged:(v)=>setState(()=>category=v??category)),vgap(18),
     Text('QUANTITY',style:AppTextStyles.pixel),vgap(7),
     Row(children:[IconButton(onPressed:qty>1?()=>setState(()=>qty--):null,icon:const Icon(Icons.remove)),
       Text(qty.toString(),style:AppTextStyles.heading),
       IconButton(onPressed:()=>setState(()=>qty++),icon:const Icon(Icons.add))]),vgap(18),
     Text('PHOTO',style:AppTextStyles.pixel),vgap(7),const ActionButton('Add Photo (not enabled)',null,primary:false),vgap(18),
     if(widget.item==null)SwitchListTile(title:Text('QR Code',style:AppTextStyles.bodyBold),
       subtitle:Text('Optional. Generate when saved.',style:AppTextStyles.body),
       value:makeCode,onChanged:(v)=>setState(()=>makeCode=v))
     else ...[
       Text('QR CODE',style:AppTextStyles.pixel),vgap(7),
       ActionButton(latest?.hasQr==true?'View QR Code':'Generate QR Code',()async{
         await Navigator.push(context,MaterialPageRoute(builder:(_)=>ItemQrScreen(widget.db,latest!.id)));
         if(mounted){final item=await widget.db.getItem(latest!.id);if(mounted)setState(()=>latest=item);}
       },primary:false)],
     vgap(18),ActionButton(busy?'Saving...':'Save Changes',busy?null:save),
     if(widget.item!=null)...[vgap(18),ActionButton('Delete Item',busy?null:remove,primary:false)]
   ]));
}
class ItemQrScreen extends StatefulWidget{
 final LRepo db;final String id;const ItemQrScreen(this.db,this.id,{super.key});@override State<ItemQrScreen> createState()=>_ItemQrScreenState();
}
class _ItemQrScreenState extends State<ItemQrScreen>{
 late Future<LItem?> item;bool busy=false;
 @override void initState(){super.initState();item=widget.db.getItem(widget.id);}
 Future<void> generate()async{setState(()=>busy=true);
  try{await widget.db.makeQr(widget.id);if(mounted)setState(()=>item=widget.db.getItem(widget.id));}
  catch(e){notice(context,e);}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Item QR Code')),
  body:FutureBuilder<LItem?>(future:item,builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final it=s.data!;
    return Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
      Text(it.name,style:AppTextStyles.heading),vgap(18),
      if(it.hasQr)...[
        BorderedCard(child:QrImageView(data:it.qrCode!,version:QrVersions.auto,size:240,backgroundColor:Colors.white)),
        vgap(18),Text('This QR stays assigned to your Item.',style:AppTextStyles.body)
      ]else...[
        const Icon(Icons.qr_code_2,size:100),vgap(18),
        Text('No QR code assigned.',style:AppTextStyles.body),vgap(18),
        ActionButton(busy?'Generating...':'Generate QR Code',busy?null:generate)
      ]])));}));
}
