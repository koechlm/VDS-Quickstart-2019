
#region disclaimer =============================================================================
# PowerShell script sample for Vault Data Standard                            
#			 Autodesk Vault - Quickstart 2019  								  
# This sample is based on VDS 2019 RTM and adds functionality and rules	  
#                                                                             
# Copyright (c) Autodesk - All rights reserved.                               
#                                                                             
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  
#endregion =============================================================================

#region - version history
# Version Info - VDS Quickstart Classification 2019.1.1
	# initial version

#endregion

function mInitializeClassificationTab($ParentType, $file)
{   
	$dsWindow.FindName("txtClassificationStatus").Visibility = "Collapsed"

	if($Global:mClsTabInitialized -ne $true)
	{
		$dsDiag.Trace("...not intialized yes -> Initialize classification tab.")
		#variables, that we need in any case; limit number of server calls
		
		$Global:mAllCustentPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
		$Global:mCustentUdpDefs = $Global:mAllCustentPropDefs | Where-Object { $_.IsSys -eq $false}
		$Global:mCustentDefs = $vault.CustomEntityService.GetAllCustomEntityDefinitions()
		$Global:mClassCustentDef = $Global:mCustentDefs | Where-Object { $_.DispName -eq $UIString["Adsk.QS.Classification_00"]}
		if(-not $Global:mClassCustentDef)
		{
			$dsWindow.FindName("txtClassificationStatus").Text = $UIString["Adsk.QS.Classification_13"]
			$dsWindow.FindName("txtClassificationStatus").Visibility = "Visible"
		}
		$mClsLevelNames = ($UIString["Adsk.QS.ClassLevel_00"], $UIString["Adsk.QS.ClassLevel_01"], $UIString["Adsk.QS.ClassLevel_02"],$UIString["Adsk.QS.ClassLevel_03"])
		$Global:mClassLevelCustentDefIds = ($Global:mCustentDefs | Where-Object { $_.DispName -in $mClsLevelNames}).Id
	}
	
	Switch($ParentType)
	{
		"Dialog"
		{
			$dsDiag.Trace("Initialize Classific.Tab starts...")
			
			$Global:mFile = mGetFileObject

			#activate UI controls
			$dsWindow.FindName("cmbAvailableClasses").add_SelectionChanged({
				If($Prop["_CreateMode"].Value -eq $true -and $dsWindow.FindName("cmbAvailableClasses").SelectedIndex -gt -1) #($Prop["_XLTN_CLASS"].Value -eq "" -or -not $Prop["_XLTN_CLASS"]) -and
				{
					$dsWindow.FindName("btnAddClass").IsEnabled = $true
					#if($Prop["_CreateMode"]){ $dsWindow.FindName("btnAddClass").IsEnabled = $true}
				}
				Else { $dsWindow.FindName("btnAddClass").IsEnabled = $false}
				If($Prop["_EditMode"].Value -eq $true -and $dsWindow.FindName("txtActiveClass").Text -eq "" -and $dsWindow.FindName("cmbAvailableClasses").SelectedIndex -gt -1)
				{
					$dsWindow.FindName("btnAddClass").IsEnabled = $true
				}
			})
		
			$dsWindow.FindName("dtgrdClassProps").add_LostFocus({
			#update property values by leaving the tab 
				$dsDiag.Trace("data grid Class Props lost focus")
				try{
						Foreach($row in $dsWindow.FindName("dtgrdClassProps").Items)
						{
							$Prop[$row.Key].Value = $row.Value
						}
				}
				catch{
					$dsDiag.Trace("Error writing class properties to file properties")
				}
			}) #lostFocus
		
			mAvlblClsReset 
			mAddClsLevelCombo -ClassLevelName $UIString["Adsk.QS.ClassLevel_00"]
			
			if($Prop["_XLTN_CLASS"].Value.Length -lt 1) { $dsWindow.FindName("btnRemoveClass").IsEnabled = $false}
			if($Prop["_XLTN_CLASS"].Value.Length -gt 0) { 	$dsWindow.FindName("btnRemoveClass").IsEnabled = $true}

			$dsDiag.Trace("...not intialized yes -> section to run onetime only finishes.")
		}
		default #data sheet tab
		{
			$Global:mFile = $file
		}
	}
		
	#the file is classified if the property _XLTN_CLASS exists and a custom object equally named is found.
	if( (mSearchCustentOfCat($UIString["Adsk.QS.Classification_00"]))) #$Prop["_XLTN_CLASS"].Value.Length -gt 0 -and
	{
		$dsDiag.Trace("  1: This file is classified or classification is available")			
		$mActiveClass = @()
		$mActiveClass += mGetCustentiesByName -Name $Prop["_XLTN_CLASS"].Value #custom object names are not unique, only its Number
		If($mActiveClass.Count -eq 1)
		{	
			#region get Property Ids and Displaynames for this class
			$mClassPropDefs = mGetClassPropDefs -ClassId $mActiveClass[0].Id
			$mClsPropTable = @{}
			$mClsLevelProps = ($UIString["Adsk.QS.ClassLevel_00"], $UIString["Adsk.QS.ClassLevel_01"], $UIString["Adsk.QS.ClassLevel_02"],$UIString["Adsk.QS.ClassLevel_03"] ,$UIString["Adsk.QS.Classification_00"])

			if($Prop["_CreateMode"].Value -eq $true)
			{
				Foreach($mClsProp in $mClassPropDefs.GetEnumerator())
				{
					#filter the all classification level properties but add all class' property
					if($mClassPropDefs[$mClsProp.Key] -notin $mClsLevelProps) { $mClsPropTable.Add($mClassPropDefs[$mClsProp.Key],"--")}	
				}
			}
			else
			{
				#get the file's class property values	 edit mode
				$mFileClassProps = $vault.PropertyService.GetProperties("FILE", @($mFile.Id), $mClassPropDefs.Keys)
				Foreach($mClsProp in $mClassPropDefs.GetEnumerator())
				{
					#filter the classification property, add all others
					if($mClassPropDefs[$mClsProp.Key] -notin $mClsLevelProps)
						{
							$mClsPropTable.Add($mClassPropDefs[$mClsProp.Key], (($mFileClassProps | Where-Object { $_.PropDefId -eq ($mClsProp.Key)}).Val))
						}
				}
			} #edit mode
		} # single class for given name found
		Else{
			#option todo: handle the return of multiple using Custent Number (unique system)
		}

		$dsWindow.FindName("dtgrdClassProps").ItemsSource = $mClsPropTable

	} #custom object workspace classes available
	
	$Global:mClsTabInitialized = $true
	$dsDiag.Trace("...Initialize Classification Tab ended.")
}

function mGetClassPropDefs($ClassId) #get Properties added to this class
{
	$mClsPropInsts = @()
	$mClsPropInsts += $vault.PropertyService.GetPropertiesByEntityIds("CUSTENT", @($ClassId))
	$mClassPropList = @{}
	ForEach($mPropInst in $mClsPropInsts)
	{
		#add UDPs of the Custom Object "Class" only
		If($Global:mCustentUdpDefs | Where-Object { $_.Id -eq $mPropInst.PropDefId })
		{
			$mDispName = ($Global:mCustentUdpDefs | Where-Object { $_.Id -eq $mPropInst.PropDefId }).DispName
			$mClassPropList.Add($mPropInst.PropDefId, $mDispName)
		}				
	}
	return $mClassPropList
}

function mGetCustentiesByName([String]$Name)
{
	$mSearchString = $Name
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	#$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
	#$propDef = $propDefs | Where-Object { $_.SysName -eq "Name" }
	$propDef = $Global:mAllCustentPropDefs | Where-Object { $_.SysName -eq "Name" }
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 1 #equals 
	$srchCond.SrchTxt = $mSearchString
	$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
	$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$bookmark = ""     
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.CustEnt]'
	
	while(($searchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $searchStatus.TotalHits))
	{
		$mResultPage = $vault.CustomEntityService.FindCustomEntitiesBySearchConditions(@($srchCond),@($srchSort),[ref]$bookmark,[ref]$searchStatus)			
		If ($searchStatus.IndxStatus -ne "IndexingComplete" -or $searchStatus -eq "IndexingContent")
		{
			#check the indexing status; you might return a warning that the result bases on an incomplete index, or even return with a stop/error message, that we need to have a complete index first
			$dsWindow.FindName("txtClassificationStatus").Text = $UIString["Adsk.QS.Classification_12"]
			$dsWindow.FindName("txtClassificationStatus").Visibility = "Visible"
		}
		if($mResultPage.Count -ne 0)
		{
			$mResultAll.AddRange($mResultPage)
		}
		else { break;}
		$dsWindow.FindName("txtClassificationStatus").Visibility = "Collapsed"
		return $mResultAll				
		break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
	}
}

function mGetFileObject()
{
	$result = FindFile -fileName ($Prop["_FileName"].Value + $Prop["_FileExt"].Value)
	foreach($fileresult in $result)
	{
		if($Prop["_FilePath"].Value -eq ($vault.DocumentService.GetFolderById($fileresult.FolderId)).FullName)
		{
			$file = $fileresult
			return $file
		}
	}
	return $null
}

function mAddClassification()
{
	$dsDiag.Trace("AddClassification starts...")
	#if($Prop["_EditMode"])
	#{
		if ($Global:mFile)
		{
			$mActiveClass = @()
			$mActiveClass += mGetCustentiesByName -Name $dsWindow.FindName("cmbAvailableClasses").SelectedValue #custom object names are not unique, only its Number

			If($mActiveClass.Count -eq 1)
			{
				$mClassPropDefs = mGetClassPropDefs -ClassId $mActiveClass.Id
				$mPropsAdd = @()
				$mPropsAdd += $mClassPropDefs.Keys
			}
			{
				[System.Windows.MessageBox]::Show($UIString["Adsk.QS.Classification_10"], "Vault Data Standard", "", "Exclamation")
				return
			}
			$mPropsRemove = @()
			$mAddRemoveComment = "Added classification"
			$mFileUpdated = $vault.DocumentService.UpdateFilePropertyDefinitions(@($Global:mFile.MasterId), $mPropsAdd, $mPropsRemove, $mAddRemoveComment)		
		}
	#}
	$Prop["_XLTN_CLASS"].Value = $dsWindow.FindName("cmbAvailableClasses").SelectedValue
	$dsWindow.FindName("btnRemoveClass").IsEnabled = $true
	$dsWindow.FindName("btnAddClass").IsEnabled = $false
	mInitializeClassificationTab -ParentType "Dialog" -file $Global:mFile
	$dsDiag.Trace("...AddClassification finished.")
}

function mRemoveClassification()
{
	$dsDiag.Trace("Remove Class starts...")
	if($Prop["_EditMode"])
	{
		if ($Global:mFile)
		{
			$dsDiag.Trace("...remove class - file found")
			$mActiveClass = @()
			$mActiveClass += mGetCustentiesByName -Name $Prop["_XLTN_CLASS"].Value #custom object names are not unique, only its Number

			If($mActiveClass.Count -eq 1)
			{
				$mClassPropDefs = mGetClassPropDefs -ClassId $mActiveClass.Id
				$mPropsRemove = @()
				$mPropsRemove += $mClassPropDefs.Keys
			}
			Else{
				[System.Windows.MessageBox]::Show($UIString["Adsk.QS.Classification_10"], "Vault Data Standard", "", "Exclamation")
				return
			}
			$mMsgResult = [System.Windows.MessageBox]::Show(([String]::Format($UIString["Adsk.QS.Classification_11"],"`n", "`n")), "Vault Data Standard - CAD Client", 'YesNo', "Question")
			if($mMsgResult -eq "No") { return}

			$mAddRemoveComment = "removed classification"
			$mFileUpdated = $vault.DocumentService.UpdateFilePropertyDefinitions(@($Global:mFile.MasterId), $mPropsAdd, $mPropsRemove, $mAddRemoveComment)
		}
	}
	#reset the classification
	$dsWindow.FindName("dtgrdClassProps").ItemsSource = $null
	$Prop["_XLTN_CLASS"] = $null #remove the property from the current window's collection, otherwise it will re-attached to the file
	$dsWindow.FindName("txtActiveClass").Text = ""
	
	$dsWindow.FindName("btnRemoveClass").IsEnabled = $false
	if($dsWindow.FindName("cmbAvailableClasses").SelectedIndex -ne -1) { $dsWindow.FindName("btnAddClass").IsEnabled = $true}
	$dsDiag.Trace("...remove classification finished result=$($mFileUpdated)")
	$dsDiag.Inspect()
}


#region classification breadcrumb
function mAddClsLevelCombo ([String] $ClassLevelName, $ClsLvls) {
	$children = mGetCustentClsLevelList -ClassLevelName $ClassLevelName
	if($children -eq $null) { return }
	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbClsBrdCrmb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.ItemsSource = @($children)
	#IF (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
	$cmb.MinWidth = 140
	$cmb.HorizontalContentAlignment = "Center"
	$cmb.BorderThickness = "1,1,1,1"
	$mWindowName = $dsWindow.Name
		switch($mWindowName)
		{
			"CustomObjectTermWindow"
			{
				IF (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
			}
			default
			{
				if($dsWindow.FindName("cmbAvailableClasses").Items.Count -gt 1)
				{
					$dsWindow.FindName("cmbAvailableClasses").IsDropDownOpen = $true
				}
				if($dsWindow.FindName("cmbAvailableClasses").Items.Count -eq 0 -and $Prop["_XLTN_CLASS"].Value -eq ""){ $cmb.IsDropDownOpen = $true}
			}
		}
	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("1. SelectionChanged, Sender = $sender, $e")
			mClsLevelCmbSelectionChanged -sender $sender
		});
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb);

	#region EditMode CustomObjectTerm Window
	If ($dsWindow.Name-eq "CustomObjectTermWindow")
	{
		IF ($Prop["_EditMode"].Value -eq $true)
		{
			$_cmbNames = @()
			Foreach ($_cmbItem in $cmb.Items) 
			{
				$dsDiag.Trace("---$_cmbItem---")
				$_cmbNames += $_cmbItem.Name
			}
			$dsDiag.Trace("Combo $index Namelist = $_cmbNames")
			if ($ClsLvls[0]) #avoid activation of null ;)
			{
				$_CurrentName = $ClsLvls[0]
				$dsDiag.Trace("Current Name: $_CurrentName ")
				#get the index of name in array
				$i = 0
				Foreach ($_Name in $_cmbNames) 
				{
					$_1 = $_cmbNames.count
					$_2 = $_cmbNames[$i]
					$dsDiag.Trace(" Counter: $i von $_1 Value: $_2  and CurrentName: $_CurrentName ")
					If ($_cmbNames[$i] -eq $_CurrentName) 
					{
						$_IndexToActivate = $i
					}
					$i +=1
				}
				$dsDiag.Trace("Index of current name: $_IndexToActivate ")
				$cmb.SelectedIndex = $_IndexToActivate			
			} #end if ClsLvls[0]
		
		}
	}
	#endregion
} # addCoCombo

function mAddClsLevelCmbChild ($data) {
	$children = mGetCustentClsLevelUsesList -sender $data
	$dsDiag.Trace("check data object: $children")
	if($children -eq $null) { return }
	#Filter classification levels and classes
	#mAvlblClsReset
	$mClassLevelObjects = @() #filtered list for the 4 levels
	$mClassLevelObjects += $children | Where-Object {$_.CustEntDefId -in $Global:mClassLevelCustentDefIds}
	$mClassObjects = @() #filtered list for the class object only
	$mClassObjects += $children | Where-Object {$_.CustEntDefId -eq $Global:mClassCustentDef.Id}

	if($mClassObjects.Count -gt 0)
	{
		$dsWindow.FindName("cmbAvailableClasses").ItemsSource = $mClassObjects
		$dsWindow.FindName("cmbAvailableClasses").SelectedIndex = 0
		$dsWindow.FindName("cmbAvailableClasses").IsEnabled = $true
	}
	if($mClassObjects.Count -eq 0)
	{
		mAvlblClsReset 
	}
	$children = $mClassLevelObjects
	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbClsBrdCrmb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.ItemsSource = @($children)	
	$cmb.BorderThickness = "1,1,1,1"
	$cmb.HorizontalContentAlignment = "Center"
	$cmb.MinWidth = 140
	$mWindowName = $dsWindow.Name
		switch($mWindowName)
		{
			"CustomObjectTermWindow"
			{
				IF (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
			}
			default
			{
				if($dsWindow.FindName("cmbAvailableClasses").Items.Count -gt 1)
				{
					$dsWindow.FindName("cmbAvailableClasses").IsDropDownOpen = $true
				}
				if($dsWindow.FindName("cmbAvailableClasses").Items.Count -eq 0){ $cmb.IsDropDownOpen = $true}
				
			}
		}
	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("next. SelectionChanged, Sender = $sender")
			mClsLevelCmbSelectionChanged -sender $sender
		});
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb)
	
	$_i = $mBreadCrumb.Children.Count
	$_Label = "lblGroup_" + $_i
	$dsDiag.Trace("Label to display: $_Label - but not longer used")
	# 	$dsWindow.FindName("$_Label").Visibility = "Visible"
	
	#region EditMode for CustomObjectTerm Window
	If ($dsWindow.Name-eq "CustomObjectTermWindow")
	{
		IF ($Prop["_EditMode"].Value -eq $true)
		{
			Try
			{
				$_cmbNames = @()
				Foreach ($_cmbItem in $cmb.Items) 
				{
					$dsDiag.Trace("---$_cmbItem---")
					$_cmbNames += $_cmbItem.Name
				}
				$dsDiag.Trace("Combo $index Namelist = $_cmbNames")
				#get the index of name in array
				if ($ClsLvls[$_i-2]) #avoid activation of null ;)
				{
					$_CurrentName = $ClsLvls[$_i-2] #remember the number of breadcrumb children is +2 (delete button, and the class start with index 0)
					$dsDiag.Trace("Current Name: $_CurrentName ")
					$i = 0
					Foreach ($_Name in $_cmbNames) 
					{
						$_1 = $_cmbNames.count
						$_2 = $_cmbNames[$i]
						$dsDiag.Trace(" Counter: $i von $_1 Value: $_2  and CurrentName: $_CurrentName ")
						If ($_cmbNames[$i] -eq $_CurrentName) 
						{
							$_IndexToActivate = $i
						}
						$i +=1
					}
					$dsDiag.Trace("Index of current name: $_IndexToActivate ")
					$cmb.SelectedIndex = $_IndexToActivate
				} #end
							
			} #end try
		catch 
		{
			$dsDiag.Trace("Error activating an existing index in edit mode.")
		}
	}
	}
	#endregion
} #addCoComboChild

function mGetCustentClsLevelList ([String] $ClassLevelName) {
	try {
		$dsDiag.Trace(">> mGetCustentClsLevelList started")
		$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 1
		$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
		#$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT") global var in ADSK.QS.Classification
		$propDefs = $Global:mAllCustentPropDefs
		$propNames = @("CustomEntityName")
		$propDefIds = @{}
		foreach($name in $propNames) {
			$propDef = $propDefs | Where-Object { $_.SysName -eq $name }
			$propDefIds[$propDef.Id] = $propDef.DispName
		}
		$srchCond.PropDefId = $propDef.Id
		$srchCond.SrchOper = 3
		$srchCond.SrchTxt = $ClassLevelName
		$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
		$srchConds[0] = $srchCond
		$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
		$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
		$bookmark = ""
		$_CustomEnts = $vault.CustomEntityService.FindCustomEntitiesBySearchConditions($srchConds,$null,[ref]$bookmark,[ref]$searchStatus)
		$dsDiag.Trace(".. mGetCustentClsLevelList finished - returns $_CustomEnts <<")
		return $_CustomEnts
	}
	catch { 
		$dsDiag.Trace("!! Error in mGetCustentClsLevelList")
	}
}

function mGetCustentClsLevelUsesList ($sender) {
	try {
		$dsDiag.Trace(">> mGetCustentClsLevelUsesList started")
		$mBreadCrumb = $dsWindow.FindName("wrpClassification")
		$_i = $mBreadCrumb.Children.Count -1
		$_CurrentCmbName = "cmbClsBrdCrmb_" + $mBreadCrumb.Children.Count.ToString()
		$_CurrentClass = $mBreadCrumb.Children[$_i].SelectedValue.Name
		#[System.Windows.MessageBox]::Show("Currentclass: $_CurrentClass and Level# is $_i")
        switch($_i)
		        {
			        0 { $mSearchFilter = $UIString["Adsk.QS.ClassLevel_00"]}
			        1 { $mSearchFilter = $UIString["Adsk.QS.ClassLevel_01"]}
			        2 { $mSearchFilter = $UIString["Adsk.QS.ClassLevel_02"]}
					3 { $mSearchFilter = $UIString["Adsk.QS.ClassLevel_03"]}
			        default { $mSearchFilter = "*"}
		        }
		$_customObjects = mGetCustentClsLevelList -ClassLevelName $mSearchFilter
		$_Parent = $_customObjects | Where-Object { $_.Name -eq $_CurrentClass }

		try {
			$links = $vault.DocumentService.GetLinksByParentIds(@($_Parent.Id),@("CUSTENT"))
			$linkIds = @()
			$links | ForEach-Object { $linkIds += $_.ToEntId }
			$mLinkedCustObjects = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds)
			$dsDiag.Trace(".. mGetCustentClsLevelUsesList finished - returns $mLinkedCustObjects <<")
			return $mLinkedCustObjects #$global:_Groups
		}
		catch {
			$dsDiag.Trace("!! Error getting links of Parent Co !!")
			return $null
		}
	}
	catch { $dsDiag.Trace("!! Error in mAddCoComboChild !!") }
}

function mClsLevelCmbSelectionChanged ($sender) {
	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$position = [int]::Parse($sender.Name.Split('_')[1]);
	$children = $mBreadCrumb.Children.Count - 1
	while($children -gt $position )
	{
		$cmb = $mBreadCrumb.Children[$children]
		$mBreadCrumb.UnregisterName($cmb.Name) #unregister the name to correct for later addition/registration
		$mBreadCrumb.Children.Remove($mBreadCrumb.Children[$children]);
		$children--;
	}
	Try{
		$Prop["_XLTN_SEGMENT"].Value = $mBreadCrumb.Children[1].SelectedItem.Name
		$Prop["_XLTN_MAINGROUP"].Value = $mBreadCrumb.Children[2].SelectedItem.Name
		$Prop["_XLTN_GROUP"].Value = $mBreadCrumb.Children[3].SelectedItem.Name
		$Prop["_XLTN_SUBGROUP"].Value = $mBreadCrumb.Children[4].SelectedItem.Name
	}
	catch{}
	#$dsDiag.Trace("---combo selection = $_selected, Position $position")
	
	mAvlblClsReset

	mAddClsLevelCmbChild -sender $sender.SelectedItem
}

function mResetClassSelection
{
    $dsDiag.Trace(">> Reset Filter started...")
	$mWindowName = $dsWindow.Name
        switch($mWindowName)
		{
			"CustomObjectTermWindow"
			{
				IF ($Prop["_EditMode"].Value -eq $true)
				{
					try
					{
						$Global:_Return=[System.Windows.MessageBox]::Show($UIString["ClassTerms_MSG01"], $UIString["ClassTerms_01"], 4)
						If($_Return -eq "No") { return }
					}
					catch
					{
						$dsDiag.Trace("Error - Reset Terms Classification Filter")
					}
			}
				IF (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes"))
				{
					$mBreadCrumb = $dsWindow.FindName("wrpClassification")
					$mBreadCrumb.Children[1].SelectedIndex = -1
				}
			}
			default
			{
				$mBreadCrumb = $dsWindow.FindName("wrpClassification")
				$mBreadCrumb.Children[0].SelectedIndex = -1
			}
		}

	$dsDiag.Trace("...Reset Filter finished <<")
}

function mAvlblClsReset
{
	$dsWindow.FindName("cmbAvailableClasses").ItemsSource = $null
	$dsWindow.FindName("cmbAvailableClasses").SelectedIndex = -1
	$dsWindow.FindName("cmbAvailableClasses").IsEnabled = $false
	$dsWindow.FindName("btnAddClass").IsEnabled = $false
}
#endregion classification breadcrumb