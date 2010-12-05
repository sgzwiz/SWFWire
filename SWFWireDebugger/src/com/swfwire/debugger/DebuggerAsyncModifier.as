package com.swfwire.debugger
{
	import com.swfwire.debugger.utils.ABCWrapper;
	import com.swfwire.debugger.utils.InstructionLocation;
	import com.swfwire.debugger.utils.InstructionTemplate;
	import com.swfwire.decompiler.abc.ABCReaderMetadata;
	import com.swfwire.decompiler.abc.instructions.*;
	import com.swfwire.decompiler.abc.tokens.*;
	import com.swfwire.decompiler.abc.tokens.multinames.*;
	import com.swfwire.decompiler.abc.tokens.traits.*;
	import com.swfwire.decompiler.data.swf.SWF;
	import com.swfwire.decompiler.data.swf.SWFHeader;
	import com.swfwire.decompiler.data.swf.tags.*;
	import com.swfwire.decompiler.data.swf9.tags.*;
	
	import flash.utils.getTimer;

	[Event(type="com.swfwire.debugger.events.AsyncSWFModifierEvent", name="run")]
	[Event(type="com.swfwire.debugger.events.AsyncSWFModifierEvent", name="complete")]
	
	public class DebuggerAsyncModifier extends AsyncSWFModifier
	{
		private var phase:uint;
		private var iTag:uint;
		private var swf:SWF;
		private var metadata:Vector.<ABCReaderMetadata>;
		private var deferConstructor:Boolean;
		public var foundMainClass:Boolean;
		public var mainClassPackage:String;
		public var mainClassName:String;
		public var backgroundColor:uint;
		
		public function DebuggerAsyncModifier(swf:SWF, metadata:Vector.<ABCReaderMetadata>, deferConstructor:Boolean = true, timeLimit:uint = 100)
		{
			super(timeLimit);
			
			this.swf = swf;
			this.metadata = metadata;
			this.deferConstructor = deferConstructor;
		}
		
		override public function start():Boolean
		{
			if(super.start())
			{
				phase = 1;
				iTag = 0;
				return true;
			}
			return false;
		}
		
		override protected function run():Number
		{
			switch(phase)
			{
				case 1:
					phase1();
					phase = 2;
					break;
				case 2:
					phase2();
					phase = 3;
					break;
				case 3:
					phase3();
					break;
			}
			
			return iTag/swf.tags.length;
		}
		
		protected function phase1():void
		{
			var start:uint = getTimer();
			
			swf.header.signature = SWFHeader.UNCOMPRESSED_SIGNATURE;
			
			var iTag:uint;
			
			backgroundColor = 0xFFFFFF;
			
			for(iTag = 0; iTag < swf.tags.length; iTag++)
			{
				var bgt:SetBackgroundColorTag = swf.tags[iTag] as SetBackgroundColorTag;
				if(bgt)
				{
					backgroundColor = bgt.backgroundColor.red << 16 | bgt.backgroundColor.green << 8 | bgt.backgroundColor.blue;
				}
			}
		}
		
		protected function phase2():void
		{
			var start:uint = getTimer();
			
			var mainClass:String = '';
			var iTag:uint;
			
			for(iTag = 0; iTag < swf.tags.length; iTag++)
			{
				var sct:SymbolClassTag = swf.tags[iTag] as SymbolClassTag;
				if(sct)
				{
					for(var isym:uint = 0; isym < sct.symbols.length; isym++)
					{
						if(sct.symbols[isym].characterId == 0)
						{
							mainClass = sct.symbols[isym].className;
						}
					}
				}
			}

			trace('main class: '+mainClass);
			
			foundMainClass = false;
			if(mainClass != '')
			{
				foundMainClass = true;
			}
			
			mainClassPackage = '';
			mainClassName = mainClass;
			
			if(mainClass.indexOf('.') >= 0)
			{
				mainClassName = mainClass.substr(mainClass.lastIndexOf('.') + 1);
				mainClassPackage = mainClass.substr(0, mainClass.lastIndexOf('.'));
			}			
		}
		
		protected function update(wrapper:ABCWrapper, abcTag:DoABCTag, ns:String, name:String, newNs:int = -1, newName:int = -1):void
		{
			var index :int = wrapper.getMultinameIndex(ns, name);
			if(index >= 0)
			{
				var qName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[index].data as MultinameQNameToken;
				if(newNs >= 0)
				{
					qName.ns = newNs;
				}
				if(newName >= 0)
				{
					qName.name = newName;
				}
			}
		}
		
		protected function phase3():void
		{
			if(iTag < swf.tags.length)
			{
				var abcTag:DoABCTag = swf.tags[iTag] as DoABCTag;
				if(abcTag)
				{
					var wrapper:ABCWrapper = new ABCWrapper(abcTag.abcFile, metadata[iTag]);
					
					var injectedNamespace:uint = wrapper.addNamespaceFromString('com.swfwire.debugger.injected');
					
					var securityIndex:int = wrapper.getMultinameIndex('flash.system', 'Security');
					if(securityIndex >= 0)
					{
						var securityQName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[securityIndex].data as MultinameQNameToken;
						securityQName.ns = injectedNamespace;
					}
					var externalInterfaceIndex:int = wrapper.getMultinameIndex('flash.external', 'ExternalInterface');
					if(externalInterfaceIndex >= 0)
					{
						var externalInterfaceQName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[externalInterfaceIndex].data as MultinameQNameToken;
						externalInterfaceQName.ns = injectedNamespace;
					}
					/*
					var stageIndex:int = wrapper.getMultinameIndex('', 'stage');
					if(stageIndex >= 0)
					{
						var externalInterfaceQName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[stageIndex].data as MultinameQNameToken;
						externalInterfaceQName.ns = injectedNamespace;
					}
					*/
					
					var urlLoaderIndex:int = wrapper.getMultinameIndex('flash.net', 'URLLoader');
					if(urlLoaderIndex >= 0)
					{
						var urlLoaderQName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[urlLoaderIndex].data as MultinameQNameToken;
						urlLoaderQName.ns = injectedNamespace;
					}
					
					var netConnectionIndex:int = wrapper.getMultinameIndex('flash.net', 'NetConnection');
					if(netConnectionIndex >= 0)
					{
						var netConnectionQName:MultinameQNameToken = abcTag.abcFile.cpool.multinames[netConnectionIndex].data as MultinameQNameToken;
						netConnectionQName.ns = injectedNamespace;
					}
					
					update(wrapper, abcTag, 'flash.display', 'Loader', injectedNamespace, -1);
					//update(wrapper, abcTag, 'flash.display', 'Sprite', injectedNamespace, -1);
					//update(wrapper, abcTag, 'flash.display', 'LoaderInfo', injectedNamespace, wrapper.addString('SWFWire_LoaderInfo'));
					//update(wrapper, abcTag, '', 'loaderInfo', -1, wrapper.addString('swfWire_loaderInfo'));
					
					var mainIndex:int = wrapper.getMultinameIndex(mainClassPackage, mainClassName);
					var mainInst:InstanceToken = null;
					
					if(mainIndex >= 0)
					{
						for(var i:uint = 0; i < abcTag.abcFile.instances.length; i++)
						{
							var inst:InstanceToken = abcTag.abcFile.instances[i];
							if(inst.name == mainIndex)
							{
								mainInst = inst;
								break;
							}
						}
					}
					
					if(mainInst && deferConstructor)
					{
						var mainMB:MethodBodyInfoToken = wrapper.findMethodBody(mainInst.iinit);
						
						//Create method deferredConstructor on main class
						var defcmni:int = wrapper.addQName(
							wrapper.addNamespaceFromString(''), 
							wrapper.addString('deferredConstructor'));
						
						var mainTrait:TraitsInfoToken = new TraitsInfoToken(defcmni,
							TraitsInfoToken.KIND_TRAIT_METHOD,
							0,
							new TraitMethodToken(0, mainInst.iinit));
						
						mainInst.traits.push(mainTrait);
						
						//Update the readable name for the method
						/*
						var origcm:MethodInfoToken = abcTag.abcFile.methods[mainInst.iinit];
						origcm.name = wrapper.addString(mainClass+'/deferredConstructor');
						*/
						
						//Create the new constructor
						var defcmi:uint = abcTag.abcFile.methods.push(new MethodInfoToken()) - 1;
						
						var emptyMethod:MethodBodyInfoToken = new MethodBodyInfoToken(
							defcmi, 1, 1, mainMB.initScopeDepth, mainMB.initScopeDepth + 1);
						emptyMethod.instructions = wrapper.getEmptyConstructorInstructions();
						
						abcTag.abcFile.methodBodies.push(emptyMethod);
						
						//mainMB.method = defcmi;
						
						mainInst.iinit = defcmi;
						
						//mainInst.iinit = fci;
					}
					
					//Debug.log('test', 'after', mainInst.traits);
					
					//mainInst.iinit--;
					
					if(true)
					{
						var cp:ConstantPoolToken = abcTag.abcFile.cpool;
						var l:*;
						const minScopeDepth:uint = 3;
						
						var loggerClassIndex:int = wrapper.addQName(
							wrapper.addNamespaceFromString('com.swfwire.debugger.injected'), 
							wrapper.addString('Logger'));
						
						var emptyNS:int = wrapper.addNamespaceFromString('');
						
						var enterFunctionIndex:int = wrapper.addQName(emptyNS, wrapper.addString('enterFunction'));
						var exitFunctionIndex:int = wrapper.addQName(emptyNS, wrapper.addString('exitFunction'));
						
						var traceIndex:int = wrapper.getMultinameIndex('', 'trace');
						if(traceIndex >= 0)
						{
							l = wrapper.findInstruction(new InstructionTemplate(Instruction_findpropstrict, {index: traceIndex}));
							
							for(var iter:* in l)
							{
								abcTag.abcFile.methodBodies[l[iter].methodBody].maxStack += 1;
							}
							
							wrapper.replaceInstruction2(l, function(z:*, a:Vector.<IInstruction>):Vector.<IInstruction>
							{
								var b:Vector.<IInstruction> = new Vector.<IInstruction>();
								b.push(new Instruction_getlex(loggerClassIndex));
								wrapper.redirectReferences(z.methodBody, a[0], b[0]);
								return b;
							});
							
							var methodIndex:int = wrapper.addQName(emptyNS, wrapper.addString('log'));
							
							l = wrapper.findInstruction(new InstructionTemplate(Instruction_callpropvoid, {index: traceIndex}));
							wrapper.replaceInstruction2(l, function(z:*, a:Vector.<IInstruction>):Vector.<IInstruction>
							{
								var b:Vector.<IInstruction> = new Vector.<IInstruction>();
								b.push(new Instruction_callpropvoid(methodIndex, Object(a[0]).argCount));
								wrapper.redirectReferences(z.methodBody, a[0], b[0]);
								return b;
							});
							
							l = wrapper.findInstruction(new InstructionTemplate(Instruction_callproperty, {index: traceIndex}));
							wrapper.replaceInstruction2(l, function(z:*, a:Vector.<IInstruction>):Vector.<IInstruction>
							{
								var b:Vector.<IInstruction> = new Vector.<IInstruction>();
								b.push(new Instruction_callproperty(methodIndex, Object(a[0]).argCount));
								wrapper.redirectReferences(z.methodBody, a[0], b[0]);
								return b;
							});
						}
						
						var nameFromMethodId:Object = {};
						
						function qnameToString(index:uint):String
						{
							var result:String = '<Not a QName>';
							var mq:MultinameQNameToken = cp.multinames[index].data as MultinameQNameToken;
							if(mq)
							{
								var ns:String = cp.strings[cp.namespaces[mq.ns].name].utf8;
								if(ns != '')
								{
									ns = ns + '::';
								}
								result = ns + cp.strings[mq.name].utf8;
							}
							return result;
						}
						
						for(var i11:int = 0; i11 < abcTag.abcFile.instances.length; i11++)
						{
							var inst2:InstanceToken = abcTag.abcFile.instances[i11];
							
							var instName:String = qnameToString(inst2.name);
							
							nameFromMethodId[inst2.iinit] = instName;
							for(var i12:int = 0; i12 < inst2.traits.length; i12++)
							{
								var name:String = qnameToString(inst2.traits[i12].name);
								var tmt:TraitMethodToken = inst2.traits[i12].data as TraitMethodToken;
								switch(inst2.traits[i12].kind)
								{
									case TraitsInfoToken.KIND_TRAIT_GETTER:
										name = 'get '+name;
										break;
									case TraitsInfoToken.KIND_TRAIT_SETTER:
										name = 'set '+name;
										break;
								}
								if(tmt)
								{
									nameFromMethodId[tmt.methodId] = instName+'/'+name;
								}
							}
						}
						
						for(var i13:int = 0; i13 < abcTag.abcFile.classes.length; i13++)
						{
							var classInfo:ClassInfoToken = abcTag.abcFile.classes[i13];
							var inst3:InstanceToken = abcTag.abcFile.instances[i13];
							
							var className:String = qnameToString(inst3.name);
							
							nameFromMethodId[classInfo.cinit] = className+'$cinit';
							
							for(var i14:int = 0; i14 < classInfo.traits.length; i14++)
							{
								var name2:String = qnameToString(classInfo.traits[i14].name);
								var tmt2:TraitMethodToken = classInfo.traits[i14].data as TraitMethodToken;
								switch(classInfo.traits[i14].kind)
								{
									case TraitsInfoToken.KIND_TRAIT_GETTER:
										name = 'get '+name;
										break;
									case TraitsInfoToken.KIND_TRAIT_SETTER:
										name = 'set '+name;
										break;
								}
								if(tmt2)
								{
									nameFromMethodId[tmt2.methodId] = className+'$/'+name2;
								}
							}
						}
						
						l = wrapper.findInstruction(new InstructionTemplate(Instruction_newfunction, {}));
						for(var i15:int = 0; i15 < l.length; i15++)
						{
							var mb2:MethodBodyInfoToken = abcTag.abcFile.methodBodies[l[i15].methodBody];
							var newfinst:Instruction_newfunction = mb2.instructions[l[i15].id] as Instruction_newfunction;
							nameFromMethodId[newfinst.index] = nameFromMethodId[mb2.method]+'/<anonymous>';
						}
						
						//Debug.dump(nameFromMethodId, 20);
						
						for(var i9:int = 0; i9 < abcTag.abcFile.methodBodies.length; i9++)
						{
							var mb:MethodBodyInfoToken = abcTag.abcFile.methodBodies[i9];
							
							if(!nameFromMethodId[mb.method])
							{
								//trace('Couldn\'t find a method name for '+mb.method);
							}
							
							if(mb.initScopeDepth >= minScopeDepth)
							{
								var j9:* = abcTag.abcFile.methodBodies[i9].instructions;
								
								var paramCount:uint = abcTag.abcFile.methods[mb.method].paramCount;
								
								
								j9.unshift(new Instruction_callpropvoid(enterFunctionIndex, 3));
								
								if(paramCount > 0)
								{
									abcTag.abcFile.methodBodies[i9].maxStack += paramCount * 2 + 3;
									j9.unshift(new Instruction_newobject(paramCount));
									
									for(var i10:int = paramCount - 1; i10 >= 0; i10--)
									{
										var paramName:ParamInfoToken = abcTag.abcFile.methods[mb.method].paramNames[i10];
										j9.unshift(new Instruction_getlocal(i10 + 1));
										if(paramName && paramName.value > 0)
										{
											j9.unshift(new Instruction_pushstring(paramName.value));
										}
										else
										{
											j9.unshift(new Instruction_pushstring(wrapper.addString('param'+i10)));
										}
									}
								}
								else
								{
									abcTag.abcFile.methodBodies[i9].maxStack += 4;
									j9.unshift(new Instruction_pushnull());
								}
								
								j9.unshift(new Instruction_getlocal0());
								
								var methodId:int =  wrapper.addString(iTag+'.'+String(i9));
								var methodName:String = nameFromMethodId[mb.method];
								if(methodName)
								{
									methodId =  wrapper.addString(methodName);
								}
								j9.unshift(new Instruction_pushstring(methodId));
								j9.unshift(new Instruction_getlex(loggerClassIndex));
							}
						}
						
						
						l = wrapper.findInstruction(new InstructionTemplate(Instruction_returnvoid, {}));
						
						for(var iter6:* in l)
						{
							abcTag.abcFile.methodBodies[l[iter6].methodBody].maxStack += 1;
						}
						
						wrapper.replaceInstruction2(l, function(z:InstructionLocation, a:Vector.<IInstruction>):Vector.<IInstruction>
						{
							var mb:MethodBodyInfoToken = abcTag.abcFile.methodBodies[z.methodBody];
							if(mb.initScopeDepth >= minScopeDepth)
							{
								a.unshift(new Instruction_callpropvoid(exitFunctionIndex, 1));
								
								var methodId:int =  wrapper.addString(iTag+'.'+z.methodBody);
								var methodName:String = nameFromMethodId[mb.method];
								if(methodName)
								{
									methodId =  wrapper.addString(methodName);
								}
								a.unshift(new Instruction_pushstring(methodId));
								
								a.unshift(new Instruction_getlex(loggerClassIndex));
							}
							wrapper.redirectReferences(z.methodBody, a[a.length - 1], a[0]);
							return a;
						});
						
						l = wrapper.findInstruction(new InstructionTemplate(Instruction_returnvalue, {}));
						
						for(iter6 in l)
						{
							abcTag.abcFile.methodBodies[l[iter6].methodBody].maxStack += 1;
						}
						
						wrapper.replaceInstruction2(l, function(z:InstructionLocation, a:Vector.<IInstruction>):Vector.<IInstruction>
						{
							var mb:MethodBodyInfoToken = abcTag.abcFile.methodBodies[z.methodBody];
							if(mb.initScopeDepth >= minScopeDepth)
							{
								a.unshift(new Instruction_callpropvoid(exitFunctionIndex, 2));
								a.unshift(new Instruction_swap());
								
								var methodId:int =  wrapper.addString(iTag+'.'+z.methodBody);
								var methodName:String = nameFromMethodId[mb.method];
								if(methodName)
								{
									methodId =  wrapper.addString(methodName);
								}
								a.unshift(new Instruction_pushstring(methodId));
								
								a.unshift(new Instruction_swap());
								a.unshift(new Instruction_getlex(loggerClassIndex));
								a.unshift(new Instruction_dup());
							}
							wrapper.redirectReferences(z.methodBody, a[a.length - 1], a[0]);
							return a;
						});
					}
				}
				iTag++;
			}
			else
			{
				finish();
			}
		}
	}
}