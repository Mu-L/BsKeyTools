/*
 * @Description: CleanVirus
 * @Author: Bullet.S
 * @Date: 2022-02-08 16:37:12
 * @LastEditors: Bullet.S
 * @LastEditTime: 2025-04-16 18:18:40
 * @Email: animator.bullet@foxmail.com
 */
-- --ALC betaclenaer
-- (globalVars.isGlobal #AutodeskLicSerStuckCleanBeta)
-- --ADSL bscript
-- (globalVars.isGlobal #ADSL_BScript)
-- --CRP bscript
-- (globalVars.isGlobal #CRP_BScript)
-- --ALC2 alpha
-- (globalVars.isGlobal #AutodeskLicSerStuckCleanAlpha)
-- --PhysXPluginMfx
-- (globalVars.isGlobal #physXCrtRbkInfoCleanBeta)
-- --ALC3 alpha
-- (globalVars.isGlobal #AutodeskLicSerStuckAlpha)
-- --Alienbrains
-- (try(TrackViewNodes.TVProperty.PropParameterLocal.count >= 0) catch(false))
-- --ShaDu
-- ((try(TrackViewNodes.AnimLayerControlManager.AnimTracks.ParamName) catch(undefined)) != undefined)

/*
[INFO] 

AUTHOR = MastaMan
DEV = 3DGROUND
SITE=http://3dground.net
MODIFY = Bullet.S
SITE = anibullet.com

[SCRIPT]

*/
struct signature_log (
	fn getLogFile = (
		d = execute ("@\"" + (getDir #maxData) + "\\scanlog.ini\"")
		return d
	), 
	
	fn getVerboseLevel = (
		ini = getLogFile()
		v = getIniSetting ini "SETTINGS" "VERBOSELEVEL"
		if(v == "") do return 1
		return try(v as integer) catch(1)
	),
	
	fn setVerboseLevel lvl = (
		ini = getLogFile()
		setIniSetting ini "SETTINGS" "VERBOSELEVEL" (lvl as string)
	),
	
	fn getLogType type = (
		return case type of (
			#threat: "Threat"
			#warn: "Warning"
			default: "Default"
		)
	),
	
	fn getTime = (
		t = #()
		for i in getLocalTime() do (
			s = (i as string)
			if(s.count < 2) do s = "0" + s
			append t s
		)
		
		return t[4] + "." + t[2] + "." + t[1] + " " + t[5] + ":" + t[6] + ":" + t[7]
	),
	
	fn write msg type: #threat = (
		ini = getLogFile()
		
		s = getLogType type
		k = getTime()
		
		setIniSetting ini s k msg
	),
	
	fn get type: #threat = (
		ini = getLogFile()
		s = getLogType type
		
		out = #()
		
		for i in (getIniSetting ini s) do (
			tmp = #()
			tmp[1] = i
			tmp[2] = s
			tmp[3] = (getIniSetting ini s i)
			append out tmp
		)
		
		return out
	),
	
	fn getAll = (
		out = #()
		ini = getLogFile()
		
		for i in (getIniSetting ini) where i != "SETTINGS" do (
							
			for ii in (getIniSetting ini i) do (
				tmp = #()
				tmp[1] = ii
				tmp[2] = i
				tmp[3] = (getIniSetting ini i ii)

				append out tmp
			)
		)
		
		return out
	),
	
	fn clearAll = (
		out = #()
		ini = getLogFile()
		
		for i in (getIniSetting ini) where i != "SETTINGS" do (
			delIniSetting ini i
		)
	)
)

(
	struct signature_worm_3dsmax_shadu (
		name = "[Worm.3dsmax.ShaDu]",
		signature = (substituteString (getFileNameFile (getThisScriptFileName())) "." "_"),				
		detect_events = #(#filePreOpen,#filePostOpen, #postImport, #systemPostNew, #systemPostReset, #filePostMerge),
		remove_ca = #("shaduA", "shaduB"),
		remove_events = #(#SHADU,#myTools),
		remove_globals = #("shaduA","shaduB"),
		remove_files = #(),
		
		slog = signature_log(),		

		fn hasCallback callbackID = 
		(
			local result = false
			local str = stringStream ""
			
			-- 将callbacks.show输出重定向到字符串流
			callbacks.show id:callbackID to:str
			
			-- 将字符串流内容转换为字符串
			local content = str as string
			
			-- 如果内容中没有"No callbacks found"且不为空，则回调存在
			result = findString content "OK" == undefined and content.count > 0
			
			return result
		),

		fn pattern v p = (
			return matchPattern (toLower (v as string)) pattern: (toLower (p as string))
		),			
			
		fn detect = (
			if hasCallback #SHADU then (true) else (false)
			isA = try(globalVars.isGlobal #shaduA) catch(false)
			isB = try(globalVars.isGlobal #shaduB) catch(false)
			if (isA and isB) then (true) else (false)
		),
		
		fn forceDelFile f = (
			try(setFileAttribute f #readOnly false) catch()
			return deleteFile (pathConfig.resolvePathSymbols f)
		), 
		
		fn getInfectedFiles = (
			dirs = #(#userStartupScripts, #startupScripts)
			out = #()
			for d in dirs do 
			(		
				files = getFiles ((getDir d) + @"\*.*")
				for find in remove_files do (
					for f in files where (findString (toLower f) (toLower find) != undefined) do append out f
				)
			)
			
			return out
		),
		
		fn removeGlobal g = (
			try(if(persistents.isPersistent g) do persistents.remove g) catch()
			try(globalVars.remove g) catch()
		),

		fn removeAttribs attrs: #() = (
			for attr in attrs do (
				for i in custattributes.getSceneDefs() where pattern i ("*" + attr + "*") do (			
					for ii in custAttributes.getDefInstances i do ( 
						for o in refs.dependents ii do (
							custAttributes.delete o (custAttributes.getDef o 1)
						)
						try(custAttributes.deleteDef ii) catch()
					)
					
					try(custAttributes.deleteDef i) catch()
				)
			)
		),
		
		fn dispose = (
			for i in 1 to detect_events.count do (
				id = i as string				
				execute ("callbacks.removeScripts id: #" + signature + id)								
			)	
		),
		
		fn register = (
			for i in 1 to detect_events.count do (
				id = i as string
				f = substituteString (getThisScriptFileName()) @"\" @"\\"
				
				execute ("callbacks.removeScripts id: #" + signature + id)
				execute ("callbacks.addScript #" + detect_events[i] as string + "  \" (fileIn @\\\"" + f + "\\\")  \" id: #" + signature + id)				
			)				
		),
		
		fn run = (			
			register()
			
			if(detect() == false) do (												
				return false
			)	
			
			removeAttribs attrs: remove_ca
			for f in getInfectedFiles() do forceDelFile f
			for ev in remove_events do try(callbacks.removeScripts id: ev) catch()
			for g in remove_globals do removeGlobal g
			
			notification = "病毒已检测到并删除完成！请注意另存文件！                                                                      "		
			displayTempPrompt  (name + " "  + notification) 10000
			
			verbose_level = slog.getVerboseLevel()
			if(verbose_level == 1 or verbose_level == 2) do (
				messageBox (name + " "  + notification) title: "Notification!"
			)
				
			if(verbose_level == 1 or verbose_level == 3) do (
				msg = name + " 病毒已从下面路径移除： \"" + (maxFilePath + maxFileName) + "\""
				slog.write msg
			)	
			if stateLoadStartupScripts == undefined then stateLoadStartupScripts = 1
			try((setinisetting (getMAXIniFile()) "MAXScript" "LoadStartupScripts" (stateLoadStartupScripts as string)))catch()
		)
	)
	
	local signature = signature_worm_3dsmax_shadu()
	signature.run()
)