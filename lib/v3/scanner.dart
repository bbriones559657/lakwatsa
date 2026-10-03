import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import 'repository.dart';

class QrScanScreen extends StatefulWidget{
 final LRepo db;final String activityId;
 final List<LActivityItem> items;final Map<String,String> previous;
 const QrScanScreen(this.db,this.activityId,this.items,this.previous,{super.key});
 @override State<QrScanScreen> createState()=>_QrScanScreenState();
}
class _QrScanScreenState extends State<QrScanScreen>{
 late final MobileScannerController scanner;
 late final Map<String,String> found;
 late final List<LActivityItem> entries;
 bool processing=false;String message='Point the camera at an Item QR code.';
 @override void initState(){super.initState();scanner=MobileScannerController(formats:[BarcodeFormat.qrCode]);
 found=Map<String,String>.from(widget.previous);entries=List<LActivityItem>.from(widget.items);}
 @override void dispose(){scanner.dispose();super.dispose();}
 Future<void> detect(BarcodeCapture capture)async{
 if(processing||capture.barcodes.isEmpty)return;
 final value=capture.barcodes.first.rawValue;
 if(value==null||value.trim().isEmpty)return;
 processing=true;
 try{
 final it=await widget.db.getItemByQr(value);
 if(!mounted)return;
 if(it==null){setState(()=>message='QR code not recognized.');return;}
 LActivityItem? match;
 for(final entry in entries){if(entry.itemId==it.id){match=entry;break;}}
 if(match!=null){
 if(found.containsKey(match.id)){setState(()=>message=match!.name+' already checked.');return;}
 setState((){found[match!.id]='QR';message=match.name+' checked.';});return;
 }
 await scanner.stop();if(!mounted)return;
 final add=await showDialog<bool>(context:context,barrierDismissible:false,builder:(d)=>AlertDialog(
 title:const Text('Item Not in Activity'),
 content:Text(it.name+' is in My Items, but is not part of this Activity.'),
 actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),
 TextButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Add to Activity'))]));
 if(!mounted)return;
 if(add==true){final added=await widget.db.addToActivity(widget.activityId,it);if(!mounted)return;
 setState((){if(!entries.any((e)=>e.id==added.id))entries.add(added);
 found[added.id]='QR';message=it.name+' added and checked.';});}
 else{setState(()=>message='Item not added.');}
 if(mounted)await scanner.start();
 }catch(e){if(mounted){setState(()=>message='Scan error: '+e.toString());try{await scanner.start();}catch(_){}}}
 finally{await Future.delayed(const Duration(milliseconds:800));processing=false;}
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,
 body:SafeArea(child:Stack(children:[
 Positioned.fill(child:MobileScanner(controller:scanner,onDetect:detect)),
 Center(child:IgnorePointer(child:Container(width:250,height:250,decoration:BoxDecoration(
 border:Border.all(color:Colors.white,width:3),borderRadius:BorderRadius.circular(8))))),
 Positioned(top:12,left:12,right:12,child:Row(children:[
 IconButton.filled(onPressed:()=>Navigator.pop(context,found),icon:const Icon(Icons.close)),
 const Spacer(),Container(color:AppColors.ink,padding:const EdgeInsets.all(10),
 child:Text(found.length.toString()+' checked',style:AppTextStyles.bodyBold.copyWith(color:Colors.white)))])),
 Positioned(left:18,right:18,bottom:25,child:Container(color:AppColors.ink,
 padding:const EdgeInsets.all(16),child:Text(message,textAlign:TextAlign.center,
 style:AppTextStyles.bodyBold.copyWith(color:Colors.white))))
 ])));
}
