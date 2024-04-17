##P2P/QUE/$case!/bin/sh
#
## -*- tcl -*- \
exec tclsh "$0" "$@"
#
# Solace Libraries
package require ::L3
package require ::L2
package require ::L1
############################################################################

#//#
# <P><B>Script Name:</B> san_DMR_large_setup.tcl</P>
# <P>
# </P><P>
# <b>Execution steps:</b><br>
# <ul>
# <li>Test Setup</li> 
# <li>Test Cleanup</li> 
# </ul>
# </P><P>
# Copyright 2005-2021 Solace Systems, Inc.  All rights reserved.
# </P>
# @author  Radu Fofuca
#//#

############################################################################
# Static Variables

# Helper procs
proc ldiff {a b} {
    foreach e $b {
        set x($e) {}
    }
    set result {}
    foreach e $a {
        if {![info exists x($e)]} {
            lappend result $e
        }
    }
    return $result
}

proc processActionList { actionList } {
    set newlist [list]
    foreach item $actionList {
        set number [lindex [split $item *] 0]
        set action [lindex [split $item *] 1]
        if {$action == ""} {
             set action $number
             set number 1
        }
        for {set i 1} {$i <= $number} {incr i +1} {
            lappend newlist $action
        }
    }
    return $newlist
}
########################################
proc lshuffle { list randomize seed} {
    if {$randomize == 1} {
        if {$seed != ""} {
            expr srand($seed)
        }
        set n [llength $list]
        for { set i 0 } { $i < $n } { incr i } {
            set j [expr {int(rand()*$n)}]
            set temp [lindex $list $j]
            set list [lreplace $list $j $j [lindex $list $i]]
            set list [lreplace $list $i $i $temp]
        }
    }
    return $list
}
########################################
proc getActive {dmrObj} {
    if {[$dmrObj info class] == "::HACluster"} {
        return [$dmrObj GetAdActive [::Const::TRUE]]
     }
     return $dmrObj
}
########################################
proc getPrimary {dmrObj} {
    if {[$dmrObj info class] == "::HACluster"} {
        return [$dmrObj GetPrimary]
     }
     return $dmrObj
}
#######################################
proc getRepPrimary {dmrObj} {
    if {[$dmrObj info class] == "::HACluster"} {
        return [$dmrObj GetRepPrimary]
     }
     return ""
}
#######################################
proc getRepActive {dmrObj msgVpn} {
    if {[$dmrObj info class] == "::HACluster"} {
        return [$dmrObj GetRepActive $msgVpn]
     } else {
        return [$dmrObj GetAdActive [::Const::TRUE]]
     }
     return ""
}
#######################################
proc getBackup {dmrObj} {
    if {[$dmrObj info class] == "::HACluster"} {
        return [$dmrObj GetBackup]
     }
     return ""
}
########################################
set rtrObjList  [lrange [::L1::Rtr::GetRtrList] 0 47]

array set ip {}
set toolIpList [list]
if {[llength [::L1::PerfHost::GetPerfHostList]] != 0} {
    set bRemoteExecute [::Const::TRUE]
    foreach perfHostObj  [::L1::PerfHost::GetPerfHostList] {
        set ip($perfHostObj) [::L1::PerfHost::GetIpAddress -perfHostObj $perfHostObj]
        lappend toolIpList $ip($perfHostObj)
    }
} else {
    set bRemoteExecute [::Const::FALSE]
}

set namePrefix [::L1::Test::GetArg -key      "-namePrefix" \
                                 -defValue ""]

set prepPerfHosts [::L1::Test::GetArg -key      "-prepPerfHosts" \
                                 -defValue [::Const::FALSE]]

if {$prepPerfHosts == [::Const::TRUE]} {
    ::PerfUtils::PrepPerfHosts -hostIps [lsort -unique $toolIpList] \
                               -wantDeploy [::Const::FALSE] \
                               -wantReboot [::Const::TRUE]
}

set defaultSeed [clock seconds]
set seed [::L1::Test::GetArg -key      "-seed" \
                                 -defValue $defaultSeed]
if {$seed != $defaultSeed} {
    expr srand($seed)
}

#### caseList is a list with these possible elements:
#   QUEUE             = persistent pub to remote queue, sub bound to queue
#   TOPIC_ON_QUEUE    = persistent pub to topic mapped to queue, sub bound to queue
#   DTE               = persistent pub to topic on dte, sub bound to dte
#   TQE               = persistent pub, sub to temporary queue
#   TTE               = persistent pub, sub to temporary topic endpoint
#   DIRECT            = direct ipub/sub
#   PROMOTE           = direct pub to topic mapped to queue, sub bound to queue
#   DEMOTE            = persistent pub to topic, sub to topic
set caseList [::L1::Test::GetArg -key       "-caseList" \
                                 -defValue  "QUEUE,TOPIC_ON_QUEUE,DTE,TQE,TTE,DIRECT,DEMOTE,PROMOTE"]
set caseList [string trim [split $caseList ,]]
set randomizeCaseList [::L1::Test::GetArg -key   "-randomizeCaseList" \
                                 -defValue  1]

set caseList [lshuffle $caseList $randomizeCaseList $seed]

set numClientsPerCase [::L1::Test::GetArg -key   "-numClientsPerCase" \
                                 -defValue  10]

set numSubscriptionsPerClient [::L1::Test::GetArg -key   "-numSubscriptionsPerClient" \
                                 -defValue  1000]

set defaultHaRedundancy               [::Const::TRUE]
set defaultHaNodes                    10
set defaultDrReplication              [::Const::TRUE]
set defaultDrSetups                   5
set defaultActionList [list \
        3*clusterDisableEnableOne \
        standaloneReloadOne \
        standaloneReloadAll \
        2*reloadActiveOne \
        2*reloadStandbyOne \
        reloadStandbyAll \
        3*smfServiceDisableEnableOne \
        3*messageBackboneServiceDisableEnableOne \
        5*haFailoverOne \
        haFailoverAll \
        3*activeLinkDisableEnableOne \
        activeLinkDisableEnableAll \
        3*dmrMsgVpnDisableEnableOne \
        dmrMsgVpnDisableEnableAll \
        linkDisableEnableAll \
        reloadActiveAll \
        ]
# TODO
#actions still to be added:
# replicationSwitchoverOne
# replicationSwitchoverAll
# clusterDeleteReAddOne
# clusterDeleteReAddAll
# linkDeleteReAddOne
# linkDeleteReAddAll
# upgrade
#
set defaultNumMsgVpns                 0
set defaultSdkList                    [::Const::MSG_SDK_CCSMP]
set defaultUseClusterShowCmds         [::Const::TRUE]
set defaultExtendedChecks             [::Const::TRUE]
set defaultSleepInAction              10 

set testName "san_DMR_${namePrefix}_"
::L2::Test::Start -name  $testName

set haRedundancy [::L1::Test::GetArg -key "-haRedundancy" \
                                     -defValue $defaultHaRedundancy]

set haNodes [::L1::Test::GetArg -key "-haNodes" \
                                -defValue $defaultHaNodes]

if {$haRedundancy == [::Const::FALSE]} {
   set haNodes 0
}

set drReplication [::L1::Test::GetArg -key "-drReplication" \
                                      -defValue $defaultDrReplication]

set drSetups [::L1::Test::GetArg -key "-drSetups" \
                                 -defValue $defaultDrSetups]

if {$drReplication == [::Const::FALSE]} {
   set drSetups 0
}

set actionList [::L1::Test::GetArg -key "-actionList" \
                                   -defValue $defaultActionList]
set randomizeActionList [::L1::Test::GetArg -key "-randomizeActionList" \
                                            -defValue 1]
if {[llength $actionList] == 1} {
    set actionList [string trim [split $actionList ,]]
}
set actionList [processActionList $actionList]
set actionList [lshuffle $actionList $randomizeActionList $seed]

set randomizeActionTarget [::L1::Test::GetArg -key "-randomizeActionTarget" \
                                              -defValue 1]

set sleepInAction [::L1::Test::GetArg -key "-sleepInAction" \
                                      -defValue $defaultSleepInAction]

set sdkList [::L1::Test::GetArg -key "-sdkList" \
                                -defValue $defaultSdkList]
set sdkList [string trim [split $sdkList ,]]

set useClusterShowCmds [::L1::Test::GetArg -key "-useClusterShowCmds" \
                                          -defValue $defaultUseClusterShowCmds]

set extendedChecks [::L1::Test::GetArg -key "-extendedChecks" \
                                       -defValue $defaultExtendedChecks]

set connectViaUseFqdn [::L1::Test::GetArg -key "-connectViaUseFqdn" \
                                          -defValue "random"]

set diskWwnList [::L1::Test::GetArg -key "-diskWwn" \
                                    -defValue   ""]
set diskWwnList [string trim [split $diskWwnList ,]]

set destLoad   [::L1::Test::GetArg -key "-toLoadNum" \
                                  -defValue ""]

set upgradeEdition   [::L1::Test::GetArg -key "-upgradeEdition" \
                                  -defValue "enterprise"]

set actionNum 1
::L1::Test::ActionStart "$actionNum - Test Setup: Prepare test"
###################################################################################################
set actionList [lshuffle $actionList $randomizeActionList $seed]

set monitorObjList    [::L1::Rtr::GetMonitoringNodeList $rtrObjList]
set messagingObjList  [::L1::Rtr::GetMessagingNodeList  $rtrObjList]
set 100scaleObjList   [list]
set standaloneObjList [list]
set haObjList         [list]
array set myQueue {}
array set myDte {}
set clientList ""

foreach rtrObj $messagingObjList {
    if {[$rtrObj GetProperty [::RtrProp::PLATFORM_SCALING_TIER]] == 100} {
        set messagingObjList [ldiff $messagingObjList $rtrObj]
        lappend 100scaleObjList $rtrObj
    }
}
# calculate the max number of HA nodes we can get if "max" was asked for
set redFactor 2
if { [::L1::Rtr::IsVMR] } { set redFactor 3 }

set numMessagingObj [llength $messagingObjList]
set numMonitorObj   [llength $monitorObjList]
if {$haNodes == "max"} {
    set haNodes [expr min($numMessagingObj/2,max($numMonitorObj,($numMonitorObj + ($numMessagingObj - (2*$numMonitorObj))/ $redFactor)))]
}

if { [::L1::Rtr::IsVMR] } {
    # do we have enough monitor nodes for this?  if not, use some of the messaging nodes as monitor nodes for this test
    # give priority to the 100 scale tier messaging routers if any
    foreach rtrObj $100scaleObjList {
        if {[llength $monitorObjList] < $haNodes } {
            lappend monitorObjList $rtrObj
            set 100scaleObjList [ldiff $100scaleObjList $rtrObj]
        } else {
            break
        }
   }
    foreach rtrObj $messagingObjList {
        if {[llength $monitorObjList] < $haNodes } {
            lappend monitorObjList $rtrObj
            set messagingObjList [ldiff $messagingObjList $rtrObj]
        } else {
            break
        }
    }
}
set numMessagingObj [llength $messagingObjList]
set numMonitorObj   [llength $monitorObjList]


if {$drSetups == "max"} {
    set drSetups [expr ($numMessagingObj -$haNodes) / 2]
}

### the section below groups the routers in ha clusters, DR setups etc
### make any changes with *extreme* caution
set _usedHa  0
set _usedMsg 0
set _usedMon 0

for {set d 1} {$d <= $drSetups} {incr d +1} {
    if {$_usedHa < $haNodes} {
        # replication site1 is HA redundant if resources exist
        set p   [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set b   [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set m   [lindex $monitorObjList   $_usedMon]
        incr _usedMon +1
        incr _usedHa  +1  
    } else {
       # if out of HA resources then replication site1 is non-redundant
        set p   [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set b   ""  
        set m   ""  
    }
    if {$_usedHa < $haNodes} {
        # replication site2 is HA redundant if resources exist
        set rp  [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set rb  [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set rm  [lindex $monitorObjList   $_usedMon]
        incr _usedMon +1
        incr _usedHa  +1  
    } else {
       # if out of HA resources then replication site2 is non-redundant
        set rp  [lindex $messagingObjList $_usedMsg]
        incr _usedMsg +1
        set rb  ""  
        set rm  ""  
    }
    lappend haObjList [list $p $b $m $rp $rb $rm]
}
for {set h $_usedHa} {$h < $haNodes} {incr h +1} {
    # non-replicated dmr node is HA redundant until depleting the haNodes
    set p   [lindex $messagingObjList $_usedMsg]
    incr _usedMsg +1
    set b   [lindex $messagingObjList $_usedMsg]
    incr _usedMsg +1
    set m   [lindex $monitorObjList   $_usedMon]
    incr _usedMon +1
    set rp  ""
    set rb  ""
    set rm  ""
    lappend haObjList [list $p $b $m $rp $rb $rm]
}
# all the "leftovers" from the above processing are non-redundant 
set standaloneObjList [lrange $messagingObjList $_usedMsg end]

# some math to stop the script if insufficient routers for the specified haNodes, drSetups
if {$drSetups > [expr ($numMessagingObj -$haNodes) / 2]} {
    ::L1::Rtr::AssertRtrs -numRtrs [expr 2 + $drSetups + ($haNodes * $redFactor)]
}
if {$haRedundancy == [::Const::FALSE]} {
    ::L1::Rtr::AssertRtrs -numRtrs 2
} else {
    if {$haNodes == 1} {
        ::L1::Rtr::AssertRtrs -numRtrs [expr ($haNodes * $redFactor) + 1]
    } else {
        ::L1::Rtr::AssertRtrs -numRtrs [expr $haNodes * $redFactor]
    }
}
####################################################################################################
set PUB_SUB_PROFILE    "PUB_SUB_PROFILE"
set PUB_SUB_USER       "PUB_SUB_USER"
set PUB_SUB_PASSWORD   "PUB_SUB_PASSWORD"

set BRIDGE_NAME        "InterClusterBridge"
set BRIDGE_QUEUE_NAME  "BridgeQueue"

set QUEUE_PREFIX           "Q_"
set TOPIC_ENDPOINT_PREFIX  "DTE_"
set MSG_VPN_PREFIX         "MSGVPN_"
set MYCLUSTER               ""

if {[::L1::Rtr::IsCapable [::RtrProp::CAP_10_0_0]] == [::Const::TRUE]} {
    set CERT_CN ""
} else {
    set CERT_CN             [::Props::GetStringProperty [::Props::BRIDGE_CLIENT_CERT_CN_STRING]]
}

####################################################################################################
set timestamp [clock seconds]
set directTopicsList ""
set persistentTopicsList ""
set topicsList ""
array set testTopic {}
foreach case "TOPIC_ON_QUEUE DTE TQE TTE DEMOTE"  { 
    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
        for {set t 1} {$t <= $numSubscriptionsPerClient} {incr t +1} {
            set testTopicList($case,$c) "$case/test/topic/$timestamp/$c/$t" 
            set topicsList "$topicsList $testTopicList($case,$c)"
        }
        set persistentTopicsList "$persistentTopicsList $case/test/topic/$timestamp/$c/>"
    }
}
foreach case "DIRECT PROMOTE"  { 
    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
        for {set t 1} {$t <= $numSubscriptionsPerClient} {incr t +1} {
            set testTopicList($case,$c) "$case/test/topic/$timestamp/$c/$t" 
        }
        set directTopicsList "$directTopicsList $case/test/topic/$timestamp/$c/>"
    }
}
foreach case "QUEUE"  { 
    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
        set testTopicList($case,$c) "#P2P/QUE/${QUEUE_PREFIX}_${c}_${case}" 
        set topicsList "$topicsList $testTopicList($case,$c)"
        set persistentTopicsList "$persistentTopicsList $testTopicList($case,$c)"
    }
}

array set msgType {}
foreach case "QUEUE TOPIC_ON_QUEUE DTE TQE TTE DEMOTE" { 
    set msgType($case)   [::Const::MSG_TYPE_PERSISTENT] 
}
foreach case "DIRECT PROMOTE" { 
    set msgType($case)   [::Const::MSG_TYPE_DIRECT] 
}

::L1::Test::ActionEnd
##########################################################################################
set dmrNodeList          [list]
set rtrConfigObjList     [list]
set haClusterObjList     [list]
set haClusterObj         {}

incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Create the HA groups"
set ix 0

foreach haObj $haObjList {
    set haClusterObj [::L3::ConfigAd \
                        -rtrObjPrimary         [lindex $haObj 0] \
                        -rtrObjBackup          [lindex $haObj 1] \
                        -rtrObjMonitor         [lindex $haObj 2] \
                        -rtrObjRepPrimary      [lindex $haObj 3] \
                        -rtrObjRepBackup       [lindex $haObj 4] \
                        -rtrObjRepMonitor      [lindex $haObj 5] \
                        -diskWwn               [lindex $diskWwnList $ix] \
                        -isAA                  [::Const::FALSE] \
                        -wantActiveStandbyRole [::Const::TRUE] \
                        -action                [::Const::CFG_ADD] \
                    ]
    lappend haClusterObjList $haClusterObj
    lappend rtrConfigObjList     [lindex $haObj 0]

    incr ix +1
}

::L1::Test::ActionEnd
##########################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Find out the number of message-vpns to be used"

set dmrNodeList         "$haClusterObjList $standaloneObjList"
set rtrConfigObjList    "$rtrConfigObjList $standaloneObjList"

set NUM_MSG_VPNS  [::L1::Test::GetArg -key      "-numMsgVpns" \
                                      -defValue $defaultNumMsgVpns]
# calculate the number of message-vpns to be used if max was specified
# the minin=mum of 
#    max vpns supported by the smallest router in the router list
#    (bridges - neighbors -1) / (neighbors - 1) -1

if {$NUM_MSG_VPNS == "max"} {
    set MAX_MSG_VPNS1 10000000
    set MAX_BRIDGES   10000000
    foreach rtrObj $messagingObjList {
        set MAX_MSG_VPNS1 [expr min($MAX_MSG_VPNS1,[expr [::L1::Rtr::GetLimit $rtrObj [::RtrProp::NUM_VPN]]     - [llength [list "default"]]])]
        set MAX_MSG_VPNS1 [expr min($MAX_MSG_VPNS1,[expr [::L1::Rtr::GetLimit $rtrObj [::RtrProp::NUM_VPN_DMR]] - [llength [list "default"]]])]
        set MAX_BRIDGES   [expr min($MAX_BRIDGES,[::L1::Rtr::GetLimit $rtrObj [::RtrProp::NUM_BRIDGES]])]
    }
    set NUM_LINKS [expr [llength $standaloneObjList] + $haNodes - 1]
    set MAX_MSG_VPNS2 [expr ($MAX_BRIDGES - $NUM_LINKS)/$NUM_LINKS - [llength [list "default"]]]
    set NUM_MSG_VPNS [expr min($MAX_MSG_VPNS1,$MAX_MSG_VPNS2)]

    # handle the case when we don't have enough bridges fot that many dmr nodes, even with one message-vpn
    # in this case, we will truncate the list of nodes
    if {$NUM_MSG_VPNS < 0} {
        set NUM_MSG_VPNS  0
        set MAX_DMR_NODES [expr ($MAX_BRIDGES / 2) + 1]
        set DMR_NODES_TO_TRIM [expr [llength $dmrNodeList] - $MAX_DMR_NODES] 
        # trim standalone nodes first
        if {[llength $standaloneObjList] >= $DMR_NODES_TO_TRIM} {
            set standaloneObjList [lrange $standaloneObjList 0 end-$DMR_NODES_TO_TRIM]
        } else {
            # trim ha nodes if needed
            set DMR_NODES_TO_TRIM [expr $DMR_NODES_TO_TRIM - [llength $standaloneObjList]]
            set standaloneObjList [list]
            set haClusterObjList [lrange $haClusterObjList 0 end-$DMR_NODES_TO_TRIM] 
            set haNodes [llength $haClusterObjList]
        }
    }
}

set dmrNodeList      "$haClusterObjList $standaloneObjList"
########################################################################
set mgmtPrtcl [::Const::ITF_SEMP]
set vpnBasicAuth [::Const::AUTH_TYPE_INTERNAL]
set clientProfile    $PUB_SUB_PROFILE
set clientUsername   $PUB_SUB_USER
set PUB_RATE                100
set NUM_MSGS               1000
set PUB_WAIT_TIME           120
set NUM_MSGS_ACTION        6000
set QUEUE_DRAIN_WAIT_TIME 10000
::L1::Test::ActionEnd
##########################################################################################
incr actionNum

::L1::Test::ActionStart "$actionNum - Test Setup: Create $NUM_MSG_VPNS message-vpns"
set msgVpnList [list "default"]

for {set v 1} {$v <= $NUM_MSG_VPNS} {incr v +1} {
    set msgVpn "${MSG_VPN_PREFIX}${v}"
    lappend msgVpnList $msgVpn

    foreach rtrObj $standaloneObjList {
        ::L2::MessageVpn \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -msgVpn         $msgVpn 
    }
    foreach haClusterObj $haClusterObjList {
        ::L2::MessageVpn \
                      -haClusterObj   $haClusterObj \
                      -action         [::Const::CFG_ADD] \
                      -msgVpn         $msgVpn 
    }

    foreach rtrObj $rtrConfigObjList {

        ::L1::Authentication \
                      -rtrObj         $rtrObj \
                      -userClass      "client" \
                      -vpnName        $msgVpn \
                      -clientAuth     [::Const::AUTHENTICATION_SCHEME_BASIC] \
                      -authType       $vpnBasicAuth 

        ::L1::MessageVpnMessageSpool \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -msgVpn         $msgVpn \
                      -quota          10000 
        ::L1::ClientProfile \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -profName       $PUB_SUB_PROFILE \
                      -msgVpn         $msgVpn 
        ::L1::ClientUsername \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -clientUsername $PUB_SUB_USER \
                      -msgVpn         $msgVpn 
        ::L1::ClientUsernamePassword \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -clientUsername $PUB_SUB_USER \
                      -msgVpn         $msgVpn  \
                      -password       $PUB_SUB_PASSWORD 
        ::L1::ClientUsernameProfile \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -clientUsername $PUB_SUB_USER \
                      -msgVpn         $msgVpn  \
                      -profile        $PUB_SUB_PROFILE 
        ::L1::ClientProfileGuaranteedMessagingSend \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -profile        $clientProfile \
                      -msgVpn         $msgVpn 
        ::L1::ClientProfileGuaranteedMessagingReceive \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -profile        $clientProfile \
                      -msgVpn         $msgVpn 
       ::L1::ClientProfileGuaranteedEndpointCreate \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -profile        $clientProfile \
                      -msgVpn         $msgVpn 
       ::L1::ClientProfileAllowBridgeConnections \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -profile        $clientProfile \
                      -msgVpn         $msgVpn 
        ::L1::ClientUsernameShutdown \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_REMOVE] \
                      -clientUsername $clientUsername \
                      -msgVpn         $msgVpn 
    }
}
foreach rtrObj $rtrConfigObjList {
    ::L2::Verify::MgmtCommand \
           -cmd "::L1::ClientUsernameShutdown" \
           -params [ list \
               -rtrObj             $rtrObj \
               -msgVpn             "default" \
               -clientUsername     "default" \
               -action             [::Const::CFG_REMOVE]] 

    ::L2::ClientUsername \
           -rtrObj                  $rtrObj \
           -msgVpn                  "default" \
           -clientUsername          $PUB_SUB_USER \
           -profile                 $PUB_SUB_PROFILE \
           -password                $PUB_SUB_PASSWORD \
           -allowGuaranteedSend     [::Const::TRUE] \
           -allowGuaranteedRec      [::Const::TRUE] \
           -allowGuaranteedEndpoint [::Const::TRUE] \
           -allowBridgeConnections  [::Const::TRUE]
}

if {[::L1::Rtr::IsCapable [::RtrProp::CAP_MQTT_RETAIN]]} {
    foreach rtrObj $rtrConfigObjList {
        foreach msgVpn $msgVpnList {
           ::L1::ClientProfileAllowSharedSubscriptions \
                -rtrObj     $rtrObj \
                -msgVpn     $msgVpn \
                -profile    $PUB_SUB_PROFILE \
                -action     [::Const::CFG_ADD]
        }
    }
}
::L1::Test::ActionEnd
##########################################################################################
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "The test $testName will run with these parameters:"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "seed: $seed"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   num msg vpns              : [expr $NUM_MSG_VPNS + 1] ($NUM_MSG_VPNS + \"default\")"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   num DMR nodes in total    : [expr $haNodes + [llength $standaloneObjList]]"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   HA redundancy             : $haRedundancy"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   num HA nodes              : $haNodes"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   num standalone nodes      : [llength $standaloneObjList]"
foreach rtr $standaloneObjList {
    ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "             standalone      : [::L1::Rtr::GetRouterName $rtr]"
}
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
set _type "messaging"
foreach haObj $haObjList {
    foreach rtr $haObj {
        if {$rtr != ""} {
            if {[$rtr IsMessagingNode] == [::Const::FALSE]} { 
                set _type "monitor" 
            } else {
                set _type "messaging" 
            }
            ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "                   HA cluster: [::L1::Rtr::GetRouterName $rtr] ($_type)"
        }
    }
}
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   DR Replication            : $drReplication"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   num DR setups             : $drSetups"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   connect-via uses FQDN     : $connectViaUseFqdn"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   cases                     : $caseList"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   actions                   : $actionList"
::L1::Test::Result [::Const::LOG_RESULTS_INFO] "   -----------------------------------------------------"
##########################################################################################
if {[llength $standaloneObjList] != 0} {
    incr actionNum
    ::L1::Test::ActionStart "$actionNum - Test Setup: Init message-spool on standalone nodes"
     foreach rtrObj $standaloneObjList {
        ::L2::InitMessageSpool -rtrObj $rtrObj 
    }
    ::L1::Test::ActionEnd
}
##########################################################################################
array set perfhost {}

set index 0
if {$bRemoteExecute} {
    incr actionNum
    ::L1::Test::ActionStart "$actionNum - Test Setup: Spreading the publishers and consumers equally across perfhosts"
    foreach msgVpn $msgVpnList {
        foreach case $caseList {
            set perfHostIndex [expr $index % [llength [::L1::PerfHost::GetPerfHostList]]]
            set perfhost(PUB,$msgVpn,$case) [lindex [::L1::PerfHost::GetPerfHostList] $perfHostIndex]
            set perfhost(SUB,$msgVpn,$case) [lindex [::L1::PerfHost::GetPerfHostList] $perfHostIndex]
            incr index +1
        }
    }
    ::L1::Test::ActionEnd
}
##########################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Spreading the publishers and consumers randomly across DMR nodes "

array set node {}

foreach msgVpn $msgVpnList {
    foreach case $caseList {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
            set node(PUB,$msgVpn,$case,$c) [lindex $dmrNodeList [expr {int(rand()*[llength $dmrNodeList])}]]
            # this makes sure the pub and sub are on different dmr nodes
            set subNodeList [ldiff $dmrNodeList $node(PUB,$msgVpn,$case,$c)]
            set node(SUB,$msgVpn,$case,$c) [lindex $subNodeList [expr {int(rand()*[llength $subNodeList])}]]
        }
    }
}
::L1::Test::ActionEnd
##########################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Set routing mode to dynamic-message-routing if needed"
set rtrListToChange [list]

foreach rtrObj $standaloneObjList {
    set routingMode [::UtilsForL2::ExecL1GetValue -cmd "::L1::Show::Routing" \
                            -params [list -rtrObj $rtrObj] \
                            -xpath "//routing/mode"]
    if {$routingMode != [::Const::ROUTING_MODE_DYNAMIC]} {
        lappend rtrListToChange $rtrObj
    }
}
foreach haClusterObj $haClusterObjList {
    foreach rtrObj [list  [$haClusterObj GetPrimary] \
                          [$haClusterObj GetBackup] \
                          [$haClusterObj GetRepPrimary] \
                          [$haClusterObj GetRepBackup]] {

        if {$rtrObj != ""} {
            set routingMode [::UtilsForL2::ExecL1GetValue -cmd "::L1::Show::Routing" \
                                    -params [list -rtrObj $rtrObj] \
                                    -xpath "//routing/mode"]
            if {$routingMode != [::Const::ROUTING_MODE_DYNAMIC]} {
                lappend rtrListToChange $rtrObj
            }
        }
    }
}
::L2::RoutingMode -rtrObjList $rtrListToChange \
                  -routingMode [::Const::ROUTING_MODE_DYNAMIC]
::L1::Test::ActionEnd
############################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: If appliance, add name server"
foreach rtrObj $messagingObjList {
    if {![$rtrObj IsVMR]} {
        ::L2::Verify::MgmtCommand \
                -cmd "::L1::DnsNameServer" \
                -params [list -action    [::Const::CFG_ADD] \
                              -rtrObj    $rtrObj \
                              -ipAddr    [::Const::NAME_SERVER_IP]]
    }
}
::L1::Test::ActionEnd
##########################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Create the endpoints"

foreach msgVpn $msgVpnList {
    foreach case "QUEUE TOPIC_ON_QUEUE PROMOTE" {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

            if {[lsearch $caseList $case] != "-1"} {
                set myQueue($case,$c) "${QUEUE_PREFIX}_${c}_${case}"

                set rtrListToConfigure [list]
                set _node $node(SUB,$msgVpn,$case,$c)
                if {[$_node info class] == "::HACluster"} {
                    lappend rtrListToConfigure [$_node GetPrimary]
                } else {
                    lappend rtrListToConfigure $_node 
                }
                foreach router $rtrListToConfigure {

                    ::L2::Queue \
                       -rtrObj        $router \
                       -msgVpn        $msgVpn \
                       -name          $myQueue($case,$c) \
                       -topicsList    $testTopicList($case,$c) \
                       -permission    [::Const::CLI_ENDPOINT_PERMISSION_DELETE]

                    if {([::L1::Rtr::IsCapable [::RtrProp::CAP_DMR_REPLICATION]] == [::Const::TRUE]) && \
                        ($drSetups != 0)} {
                            ::L2::VpnReplicationTopic \
                                 -rtrObj              $router \
                                  -msgVpn             $msgVpn \
                                  -asyncTopics        $testTopicList($case,$c) \
                                  -action             [::Const::CFG_ADD]
                    }

                }
            }
        }
    }
    if {[lsearch $caseList "DTE"] != "-1"} {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
            set myDte(DTE,$c)      "${TOPIC_ENDPOINT_PREFIX}${c}"
            set rtrListToConfigure [list]
            set _node $node(SUB,$msgVpn,DTE,$c)
            if {[$_node info class] == "::HACluster"} {
                lappend rtrListToConfigure [$_node GetPrimary]
            } else {
                lappend rtrListToConfigure $_node 
            }
            foreach router $rtrListToConfigure {
                    ::L1::DurableTopicEndpoint \
                       -rtrObj        $router \
                       -action        [::Const::CFG_ADD] \
                       -msgVpn        $msgVpn \
                       -name          $myDte(DTE,$c) 
                    ::L1::DurableTopicEndpointPermission \
                       -rtrObj        $router \
                       -action        [::Const::CFG_ADD] \
                       -msgVpn        $msgVpn \
                       -name          $myDte(DTE,$c) \
                       -permission    [::Const::CLI_ENDPOINT_PERMISSION_DELETE] 
                    ::L1::TopicEndpointShutdown \
                       -rtrObj        $router \
                       -action        [::Const::CFG_REMOVE] \
                       -msgVpn        $msgVpn \
                       -name          $myDte(DTE,$c) 
            }
        }
    }
}
::L1::Test::ActionEnd
############################################################################################
array set subObj {}
array set pubObj {}
array set tte {}
array set tqe {}
array set isReplicated {}

foreach msgVpn $msgVpnList {

    incr actionNum
    ::L1::Test::ActionStart "$actionNum - Create pub/sub clients in message-vpn $msgVpn"

    foreach case $caseList {
        incr actionNum

        if {$case == "QUEUE" || $case == "TOPIC_ON_QUEUE" || $case == "DEMOTE"} {
            set pubSdk [lindex $sdkList [expr {int(rand()*[llength $sdkList])}]]
        } else {
            set pubSdk [::Const::MSG_SDK_CCSMP]
        }
        if {$case == "QUEUE" || $case == "TOPIC_ON_QUEUE" || $case == "PROMOTE"} {
            set subSdk [lindex $sdkList [expr {int(rand()*[llength $sdkList])}]]
        } else {
            set subSdk [::Const::MSG_SDK_CCSMP]
        }
        if {$bRemoteExecute} {
            set pubToolIp $ip($perfhost(PUB,$msgVpn,$case))
        } else {
            set pubToolIp ""
        }
        if {$bRemoteExecute} {
            set subToolIp $ip($perfhost(SUB,$msgVpn,$case))
        } else {
            set subToolIp ""
        }

        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
            ::L1::Test::Result [::Const::LOG_RESULTS_INFO] \
                                              "Create pub/sub clients for message-vpn $msgVpn \
                                              case: $case \
                                              pub node: $node(PUB,$msgVpn,$case,$c) \
                                              pub perfhost: $pubToolIp \
                                              pub sdk: $pubSdk \
                                              sub node: $node(SUB,$msgVpn,$case,$c) \
                                              sub perfhost: $subToolIp \
                                              sub sdk: $subSdk"

            set pubnode $node(PUB,$msgVpn,$case,$c)
            if {[$pubnode info class] == "::HACluster"} {
                set pubHaClusterObj $pubnode
                set pubRtrObj       ""
            } else {
                set pubHaClusterObj ""
                set pubRtrObj       $pubnode
            }

            set pubObj($msgVpn,$case,$c) [::L2::Client::Create \
                -remote            $bRemoteExecute \
                -remoteIp          $pubToolIp \
                -rtrObj            $pubRtrObj \
                -haClusterObj      $pubHaClusterObj \
                -username          $PUB_SUB_USER \
                -clientNamePrefix  "PUB_${case}_${c}_${msgVpn}_" \
                -password          $PUB_SUB_PASSWORD \
                -numClients        1 \
                -vpn               $msgVpn \
                -reconnectAttempts 9999 \
                -sdk               $pubSdk]
            lappend clientList $pubObj($msgVpn,$case,$c)

            set subnode $node(SUB,$msgVpn,$case,$c)
                if {[$subnode info class] == "::HACluster"} {
                set subHaClusterObj $subnode
                set subRtrObj       ""
            } else {
                set subHaClusterObj ""
                set subRtrObj       $subnode
            }

            set subObj($msgVpn,$case,$c) [::L2::Client::Create \
                  -remote            $bRemoteExecute \
                  -remoteIp          $subToolIp \
                  -rtrObj            $subRtrObj \
                  -haClusterObj      $subHaClusterObj \
                  -username          $PUB_SUB_USER \
                  -clientNamePrefix  "SUB_${case}_${c}_${msgVpn}_" \
                  -password          $PUB_SUB_PASSWORD \
                  -vpn               $msgVpn \
                  -numClients        1 \
                  -reconnectAttempts 9999 \
                  -sdk               $subSdk]
            lappend clientList $subObj($msgVpn,$case,$c)
        }
    }
    ::L1::Test::ActionEnd


    incr actionNum
    ::L1::Test::ActionStart "$actionNum - Add subscriptions,  - msgVpn: $msgVpn"

    foreach case $caseList {

        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

            switch $case \
                "TOPIC_ON_QUEUE" {
                    ::L2::Client::QueueUpdate \
                        -clientObj    $subObj($msgVpn,TOPIC_ON_QUEUE,$c) \
                        -queueList    $myQueue(TOPIC_ON_QUEUE,$c) \
                        -addFlag      [::Const::TRUE]
               } \
               "QUEUE" {
                    ::L2::Client::QueueUpdate \
                        -clientObj    $subObj($msgVpn,QUEUE,$c) \
                        -queueList    $myQueue(QUEUE,$c) \
                        -addFlag      [::Const::TRUE]
                } \
               "DTE" {
                    ::L2::Client::TopicUpdate \
                        -clientObj      $subObj($msgVpn,DTE,$c) \
                        -teList         $myDte(DTE,$c) \
                        -topicsList     $testTopicList(DTE,$c) 
                } \
                "TQE" {
                      set respKList [::L2::Client::TempQueueAdd \
                                  -clientObj  $subObj($msgVpn,TQE,$c) \
                                  -numQueues  1 ]
                      set tqe($msgVpn,$c)  [string map {\{ "" \} ""} \
                                 [keylget respKList endpoints]] 
                      ::L2::Client::MapTopics \
                                -clientObj $subObj($msgVpn,TQE,$c) \
                                -queue      $tqe($msgVpn,$c) \
                                -topicsList $testTopicList(TQE,$c)
                } \
                "TTE" {
                      set respKList [::L2::Client::TempTEAdd \
                                    -clientObj  $subObj($msgVpn,TTE,$c) \
                                    -topicsList $testTopicList(TTE,$c) \
                                    -numTEs  1 ]
                      set  tte($msgVpn,$c) [string map {\{ "" \} ""} \
                             [keylget respKList endpoints]] 
                } \
                "DIRECT" {
                     ::L2::Client::SubscriptionUpdate \
                         -clientObj        $subObj($msgVpn,DIRECT,$c) \
                         -subscriptionList $testTopicList(DIRECT,$c)
                } \
                "PROMOTE" {
                    ::L2::Client::QueueUpdate \
                          -clientObj    $subObj($msgVpn,PROMOTE,$c) \
                          -queueList    $myQueue(PROMOTE,$c) \
                          -addFlag      [::Const::TRUE]
                } \
                "DEMOTE" {
                     ::L2::Client::SubscriptionUpdate \
                         -clientObj        $subObj($msgVpn,DEMOTE,$c) \
                         -subscriptionList $testTopicList(DEMOTE,$c)
                } 
        }
    }
    ::L1::Test::ActionEnd
}
#######################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Setup: Configure the network"

# Create cluster A -> 3xReplicated HA groups

set CLUSTER_A [::L3::Clustering \
              -haClusterObjList         [lrange $haClusterObjList 0 2] \
              -clusterNamePrefix        "CLUSTER_1" \
              -transport                "ssl-compressed" \
              -span                     "internal" \
              -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
              -basicAuthType            [::Const::AUTH_TYPE_NONE] \
              -useLinkAuthentication    [::Const::TRUE] \
              -useInitiatorLexical      [::Const::FALSE] \
              -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
              -clusterPassword          "" \
              -useFqdn                  $connectViaUseFqdn \
              -trustedCommonName        $CERT_CN \
              -msgVpnList               $msgVpnList ]

foreach haClusterObj [lrange $haClusterObjList 0 2] {
    foreach rtrObj "[getPrimary $haClusterObj] [getRepPrimary $haClusterObj]" {
        if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
            ::L2::ClusterAuthenticationCertMatchingRule \
                    -rtrObj          $rtrObj \
                    -clusterName     [keylget CLUSTER_A [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                    -ruleName        "afw" \
                    -shutdown        [::Const::FALSE]
        }
    }
}

# Create cluster B -> 2xReplicated HA groups

set CLUSTER_B [::L3::Clustering \
              -haClusterObjList         [lrange $haClusterObjList 3 4] \
              -clusterNamePrefix        "CLUSTER_2" \
              -transport                "ssl-compressed" \
              -span                     "internal" \
              -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
              -basicAuthType            [::Const::AUTH_TYPE_NONE] \
              -useLinkAuthentication    [::Const::TRUE] \
              -useInitiatorLexical      [::Const::FALSE] \
              -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
              -clusterPassword          "" \
              -useFqdn                  $connectViaUseFqdn \
              -trustedCommonName        $CERT_CN \
              -msgVpnList               $msgVpnList ]

foreach haClusterObj [lrange $haClusterObjList 3 4] {
    foreach rtrObj "[getPrimary $haClusterObj] [getRepPrimary $haClusterObj]" {
        if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
            ::L2::ClusterAuthenticationCertMatchingRule \
                    -rtrObj          $rtrObj \
                    -clusterName     [keylget CLUSTER_B [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                    -ruleName        "afw" \
                    -shutdown        [::Const::FALSE]
        }
    }
}

# Create cluster C -> 2xStandalone

set CLUSTER_C [::L3::Clustering \
              -rtrObjList               [lrange $standaloneObjList 0 1] \
              -clusterNamePrefix        "CLUSTER_3" \
              -transport                "ssl-compressed" \
              -span                     "internal" \
              -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
              -basicAuthType            [::Const::AUTH_TYPE_NONE] \
              -useLinkAuthentication    [::Const::TRUE] \
              -useInitiatorLexical      [::Const::FALSE] \
              -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
              -clusterPassword          "" \
              -useFqdn                  $connectViaUseFqdn \
              -trustedCommonName        $CERT_CN \
              -msgVpnList               $msgVpnList ]

foreach rtrObj [lrange $standaloneObjList 0 1] {
    if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
        ::L2::ClusterAuthenticationCertMatchingRule \
                -rtrObj          $rtrObj \
                -clusterName     [keylget CLUSTER_C [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                -ruleName        "afw" \
                -shutdown        [::Const::FALSE]
    }
}

# Create cluster D -> 2xStandalone

set CLUSTER_D [::L3::Clustering \
              -rtrObjList               [lrange $standaloneObjList 2 4] \
              -clusterNamePrefix        "CLUSTER_4" \
              -transport                "ssl-compressed" \
              -span                     "internal" \
              -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
              -basicAuthType            [::Const::AUTH_TYPE_NONE] \
              -useLinkAuthentication    [::Const::TRUE] \
              -useInitiatorLexical      [::Const::FALSE] \
              -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
              -clusterPassword          "" \
              -trustedCommonName        $CERT_CN \
              -useFqdn                  $connectViaUseFqdn \
              -msgVpnList               $msgVpnList ]

foreach rtrObj [lrange $standaloneObjList 2 4] {
    if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
        ::L2::ClusterAuthenticationCertMatchingRule \
                -rtrObj          $rtrObj \
                -clusterName     [keylget CLUSTER_D [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                -ruleName        "afw" \
                -shutdown        [::Const::FALSE]
    }
}

# Interconnect cluster A and cluster B with mesh of external links
::L3::InterconnectClusters \
              -cluster1Data          $CLUSTER_A \
              -cluster2Data          $CLUSTER_B \
              -msgVpnList            "allCommon" \
              -gatewayTypeCluster1   "dr_Ha" \
              -gatewayTypeCluster2   "dr_Ha" \
              -useNewGatewayCluster1 [::Const::TRUE] \
              -useNewGatewayCluster2 [::Const::TRUE] \
              -connectViaUseFqdn        $connectViaUseFqdn \
              -useInitiatorLexical   [::Const::FALSE] \
              -linkTransport         "ssl-compressed"

# Interconnect cluster A and cluster D with mesh of external links
::L3::InterconnectClusters \
              -cluster1Data          $CLUSTER_A \
              -cluster2Data          $CLUSTER_D \
              -msgVpnList            "allCommon" \
              -gatewayTypeCluster1   "dr_Ha" \
              -gatewayTypeCluster2   "standalone" \
              -useNewGatewayCluster1 [::Const::TRUE] \
              -useNewGatewayCluster2 [::Const::TRUE] \
              -connectViaUseFqdn        $connectViaUseFqdn \
              -useInitiatorLexical   [::Const::FALSE] \
              -linkTransport         "ssl-compressed"

# Interconnect cluster B and cluster D with mesh of external links
::L3::InterconnectClusters \
              -cluster1Data          $CLUSTER_B \
              -cluster2Data          $CLUSTER_D \
              -msgVpnList            "allCommon" \
              -gatewayTypeCluster1   "dr_Ha" \
              -gatewayTypeCluster2   "standalone" \
              -useNewGatewayCluster1 [::Const::TRUE] \
              -useNewGatewayCluster2 [::Const::TRUE] \
              -connectViaUseFqdn        $connectViaUseFqdn \
              -useInitiatorLexical   [::Const::FALSE] \
              -linkTransport         "ssl-compressed"

# Interconnect cluster C and cluster A with static bridges
# 1. select a non-gateway node and it's DR mate for Cluster A 
#
set selectedNode_A ""
set _ISGATEWAY [::Const::FALSE]
foreach _node [keylget CLUSTER_A REDUNDANT_NODES] {
    set nodeName [::L1::Rtr::GetRouterName [$_node GetPrimary]]
    foreach L [keylget CLUSTER_A ${nodeName}.LINKS] {
        if {[keylget CLUSTER_A ${nodeName}.${L}.SPAN] == "external"} {
            set _ISGATEWAY [::Const::TRUE]
        }
    }
    if {$_ISGATEWAY == [::Const::FALSE]} {
        set selectedNode_A $_node
       break
    }
}

# 2. Select a node in cluster C
#
set selectedNode_C [lindex [keylget CLUSTER_C STANDALONE_NODES] end]

# 3. Create a bi-directional static bridge between the selected node in cluster C and the selected nodes in cluster A
#

foreach msgVpn $msgVpnList {

    foreach rtrObj [list [$selectedNode_A GetPrimary]  \
                          $selectedNode_C] {
        ::L2::Bridge     -rtrObj         $rtrObj \
                         -name           $BRIDGE_NAME \
                         -msgVpn         $msgVpn \
                         -topicsList     $directTopicsList \
                         -action         [::Const::CFG_ADD]
        ::L2::Queue      -rtrObj         $rtrObj \
                         -msgVpn         $msgVpn \
                         -name           $BRIDGE_QUEUE_NAME \
                         -topicsList     $persistentTopicsList \
                         -permission     [::Const::CLI_ENDPOINT_PERMISSION_DELETE]
    }
    foreach otherRtrObj [list [$selectedNode_A GetPrimary] \
                              [$selectedNode_A GetBackup] \
                              [$selectedNode_A GetRepPrimary] \
                              [$selectedNode_A GetRepBackup]] {
        ::L2::BridgeRemoteMessageVpn  \
                             -rtrObj         $selectedNode_C \
                             -name           $BRIDGE_NAME \
                             -msgVpn         $msgVpn \
                             -action         [::Const::CFG_ADD] \
                             -remoteMsgVpn   $msgVpn \
                             -queue          $BRIDGE_QUEUE_NAME \
                             -connectVia     "[::L1::Rtr::GetRtrMsgBackbone -rtrObj $otherRtrObj]:[::L1::Rtr::GetRtrCompressedSmfPort -rtrObj $otherRtrObj]" \
                             -interface      [::L1::Rtr::GetRoutingInterface -rtrObj $selectedNode_C] \
                             -enableSSL      [::Const::FALSE] \
                             -compressed     [::Const::TRUE] \
                             -clientUsername $PUB_SUB_USER \
                             -password       $PUB_SUB_PASSWORD
    }
    ::L2::BridgeRemoteMessageVpn  \
                         -rtrObj         [$selectedNode_A GetPrimary] \
                         -name           $BRIDGE_NAME \
                         -msgVpn         $msgVpn \
                         -action         [::Const::CFG_ADD] \
                         -remoteMsgVpn   $msgVpn \
                         -queue          $BRIDGE_QUEUE_NAME \
                         -connectVia     "[::L1::Rtr::GetRtrMsgBackbone -rtrObj $selectedNode_C]:[::L1::Rtr::GetRtrCompressedSmfPort -rtrObj $selectedNode_C]" \
                         -interface      [::L1::Rtr::GetRoutingInterface -rtrObj [$selectedNode_A GetPrimary]] \
                         -enableSSL      [::Const::FALSE] \
                         -compressed     [::Const::TRUE] \
                         -clientUsername $PUB_SUB_USER \
                         -password       $PUB_SUB_PASSWORD
}

set skipTempEndpointCheck 0

::L1::Test::ActionEnd
#######################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Verify the clusters"

foreach CLUSTER [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {

    ::L3::VerifyClustering -clusterData $CLUSTER \
                           -useClusterShowCmds    $useClusterShowCmds \
                           -extendedChecks        $extendedChecks \
                           -timeout               120000 \
                           -pubsub                [::Const::FALSE] 
}
::L1::Test::ActionEnd
######################################################################################
# wait for all subscriptions to propagate
incr actionNum
::L1::Test::ActionStart "$actionNum - Wwit for all subscriptions to propagate"
sleep 180
::L1::Test::ActionEnd
############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Start publishers"
        
sleep 1
 
foreach msgVpn $msgVpnList {
    foreach case $caseList {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
            
            ::L2::Client::StartPublishing \
                        -clientObj        $pubObj($msgVpn,$case,$c) \
                        -numMsgs          $NUM_MSGS \
                        -topicsList       $testTopicList($case,$c) \
                        -attachSizeList   100 \
                        -rateInMsgsPerSec $PUB_RATE \
                        -msgType          $msgType($case) 
         }
     }
} 
::L1::Test::ActionEnd
############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Stop publishers"
foreach msgVpn $msgVpnList {
     foreach case $caseList {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
    
            ::L2::Client::WaitUntilDonePublishing \
                    -clientObj        $pubObj($msgVpn,$case,$c) \
                    -waitTime         $PUB_WAIT_TIME
            ::L2::Client::StopPublishing -clientObj $pubObj($msgVpn,$case,$c)
        }
    }
}
sleep 5
::L1::Test::ActionEnd
#############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Wait for all #cluster queues to drain"
foreach msgVpn $msgVpnList {
    foreach dmrNode $dmrNodeList {

        set retKList [::L1::Show::Queue \
                          -rtrObj [getActive $dmrNode] \
                          -name "#cluster:*"\
                          -msgVpn $msgVpn ]

        set domObj [[keylget retKList "domObj"] documentElement]
        set qNodes [$domObj selectNodes "//queues/queue"]
 
        foreach qNode $qNodes {
 
            set qName [::SolDom::GetElementTextFromNode $qNode "name"]
            if {$qName != ""} {
                ::L2::Verify::Queue \
                      -rtrObj [getActive $dmrNode] \
                      -msgVpn $msgVpn \
                      -name $qName \
                      -timeout $QUEUE_DRAIN_WAIT_TIME \
                      -numMessagesSpooled 0
 
            }
        }
    }
}
::L1::Test::ActionEnd
#############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Check client stats"
    
foreach msgVpn $msgVpnList {
    foreach case $caseList {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

            set _txStatsKList [::L1::Client::GetStats -clientObj $pubObj($msgVpn,$case,$c)]
            set tx [keylget _txStatsKList [::Const::STAT_TX_MSGS]]
            ::L1::Client::ResetStats $pubObj($msgVpn,$case,$c)
    
            set _rxStatsKList [::L1::Client::GetStats -clientObj $subObj($msgVpn,$case,$c)]
            set rx [keylget _rxStatsKList [::Const::STAT_RX_MSGS]]
            ::L1::Client::ResetStats $subObj($msgVpn,$case,$c)
    
            if {($msgType($case) == [::Const::MSG_TYPE_PERSISTENT]) && ($rx < $tx)} {
                ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                     "client stats: before action:\
                      case: $case, client $c, msgVpn: $msgVpn, \
                      pub: $msgType($case) on $node(PUB,$msgVpn,$case,$c) \
                      to topic:$testTopicList($case,$c), \
                      sub on $node(SUB,$msgVpn,$case,$c), \
                      pub/sub: Rx= $rx, Tx= $tx (delta= [expr $tx - $rx])"
             } elseif {$rx < [expr $tx/2]} {
                 ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                     "client stats: before action:\
                      case: $case, client $c, msgVpn: $msgVpn, \
                      pub: $msgType($case) on $node(PUB,$msgVpn,$case,$c) \
                      to topic:$testTopicList($case,$c), \
                      sub on $node(SUB,$msgVpn,$case,$c), \
                      pub/sub: Rx= $rx, Tx= $tx (delta= [expr $tx - $rx])"
            }
         }
    }
}
::L1::Test::ActionEnd
################################################################################################################################
 
set ACTION_NUMBER 0 
 
set actionListWithTraffic [ldiff $actionList \
                                 [ldiff $actionList [list \
                                                          "haFailoverOne" \
                                                          "haFailoverAll" \
                                                          "replicationSwitchoverOne" \
                                                          "replicationSwitchoverAll" \
                                                          "reloadStandbyOne" \
                                                          "reloadStandbyAll" \
                                                          "reloadActiveOne" \
                                                          "reloadActiveAll" \
                                                          "clusterDisableEnableOne" \
                                                          "linkDisableEnableOne" \
                                                          "upgrade"]]]

##################################################################################################################
 
foreach action $actionList {
 
    if {$action == "none"} {
        continue
    }
 
    incr ACTION_NUMBER +1 
 
    # start traffic during action
    if {[lsearch $actionListWithTraffic $action] != "-1"} {
                         
        incr actionNum
        ::L1::Test::ActionStart "$actionNum - Starting publishers of traffic during action ${ACTION_NUMBER}/[llength $actionList] $action"
 
        foreach msgVpn $msgVpnList {
            foreach case $caseList {
                for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
                    ::L1::Client::ResetStats $pubObj($msgVpn,$case,$c)
                    ::L1::Client::ResetStats $subObj($msgVpn,$case,$c)
                }
            }
        }
        foreach msgVpn $msgVpnList {
            foreach case $caseList {
                for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
 
                    ::L2::Client::StartPublishing \
                            -clientObj        $pubObj($msgVpn,$case,$c) \
                            -numMsgs          5000000 \
                            -topicsList       $testTopicList($case,$c) \
                            -attachSizeList   10 \
                            -rateInMsgsPerSec 100 \
                            -msgType          $msgType($case)
                }
            }
        }
        ::L1::Test::ActionEnd
    }
    ##########################################################################################################
    incr actionNum
    ::L1::Test::ActionStart "$actionNum - Performing action ${ACTION_NUMBER}/[llength $actionList] $action"

    switch $action {
               "standaloneReloadOne"   {
                    set rtrObj [lindex [lshuffle $standaloneObjList $randomizeActionTarget $seed] 0]
                    ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $rtrObj"
                    ::L2::ParallelRtrReload -rtrObjList $rtrObj
                    set skipTempEndpointCheck 1
                    sleep 30
               } "standaloneReloadAll"   {
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $standaloneObjList"
                     ::L2::ParallelRtrReload -rtrObjList $standaloneObjList
                     set skipTempEndpointCheck 1
                    sleep 30
               } "reloadAll"   {
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $rtrObjList"
                     ::L2::ParallelRtrReload -rtrObjList $rtrObjList
                     set skipTempEndpointCheck 1
                     sleep 30
               } "reloadActiveOne"   {
                     set haClusterObj [lindex [lshuffle $haClusterObjList $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $haClusterObj"
                     ::L2::ParallelRtrReload -rtrObjList [$haClusterObj  GetAdActive [::Const::TRUE]]
                     foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                        ::L2::Verify::Redundancy \
                             -rtrObj           $rtr \
                             -timeout          120000 \
                             -redundancyStatus "Up"
                     }
                     sleep $sleepInAction
                     set skipTempEndpointCheck 1
                     sleep 30
               } "reloadStandbyOne"   {
                     set haClusterObj [lindex [lshuffle $haClusterObjList $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $haClusterObj"
                     ::L2::ParallelRtrReload -rtrObjList [$haClusterObj  GetAdStandby [::Const::TRUE]]
                     foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                        ::L2::Verify::Redundancy \
                             -rtrObj           $rtr \
                             -timeout          60000 \
                             -redundancyStatus "Up"
                     }
                     sleep $sleepInAction
                     set skipTempEndpointCheck 1
                     sleep 30
               } "reloadActiveAll"   {
                     set activeRtrList [list]
                     foreach haClusterObj $haClusterObjList {
                         lappend activeRtrList [$haClusterObj  GetAdActive [::Const::TRUE]] 
                     }
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $activeRtrList"
                     ::L2::ParallelRtrReload -rtrObjList $activeRtrList
                     foreach haClusterObj $haClusterObjList {
                         foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                            ::L2::Verify::Redundancy \
                                 -rtrObj           $rtr \
                                 -timeout          60000 \
                                 -redundancyStatus "Up"
                         }
                     }
                     sleep $sleepInAction
                     set skipTempEndpointCheck 1
                     sleep 30
               } "reloadStandbyAll"   {
                     set standbyRtrList [list]
                     foreach haClusterObj $haClusterObjList {
                         lappend standbyRtrList [$haClusterObj  GetAdStandby [::Const::TRUE]] 
                     }
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $standbyRtrList"
                     ::L2::ParallelRtrReload -rtrObjList $standbyRtrList
                     foreach haClusterObj $haClusterObjList {
                         foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                            ::L2::Verify::Redundancy \
                                 -rtrObj           $rtr \
                                 -timeout          60000 \
                                 -redundancyStatus "Up"
                         }
                     }
                     sleep $sleepInAction
                     sleep 30
               } "smfServiceDisableEnableOne" {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj"

                    ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                              -params [list   -rtrObj  $rtrActiveObj \
                                              -service [::Const::SERVICE_SMF] \
                                              -action  [::Const::CFG_ADD] ]
                     ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                           -name $CLUSTER_NAME \
                                           -oper-up "false" \
                                           -oper-fail-reason "Service SMF Disabled"
                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                               -params [list   -rtrObj  $rtrActiveObj \
                                               -service [::Const::SERVICE_SMF] \
                                               -action  [::Const::CFG_REMOVE] ]
               } "smfServiceDisableEnableAll"   {
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {

                            ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                                      -params [list   -rtrObj  $rtrActiveObj \
                                                      -service [::Const::SERVICE_SMF] \
                                                      -action  [::Const::CFG_ADD] ]
                            ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                                  -name $CLUSTER_NAME \
                                                  -oper-up "false" \
                                                  -oper-fail-reason "Service SMF Disabled"
                         }
                     }
                     sleep $sleepInAction
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {

                            ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                                      -params [list   -rtrObj  $rtrActiveObj \
                                                      -service [::Const::SERVICE_SMF] \
                                                      -action  [::Const::CFG_REMOVE] ]
                         }
                    }
               } "messageBackboneServiceDisableEnableOne"   {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj"

                     ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                               -params [list   -rtrObj  $rtrActiveObj \
                                               -service [::Const::SERVICE_MSG_BACKBONE] \
                                               -action  [::Const::CFG_ADD] ]
                      ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                            -name $CLUSTER_NAME \
                                            -oper-up "false" \
                                            -oper-fail-reason "Service MsgBackbone Disabled"

                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                               -params [list   -rtrObj  $rtrActiveObj \
                                               -service [::Const::SERVICE_MSG_BACKBONE] \
                                               -action  [::Const::CFG_REMOVE] ]
               } "messageBackboneServiceDisableEnableAll"  {
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {

                             ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                                       -params [list   -rtrObj  $rtrActiveObj \
                                                       -service [::Const::SERVICE_MSG_BACKBONE] \
                                                       -action  [::Const::CFG_ADD] ]
                             ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                                   -name $CLUSTER_NAME \
                                                   -oper-up "false" \
                                                   -oper-fail-reason "Service MsgBackbone Disabled"
                         }
                     }
                     sleep $sleepInAction
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"

                         foreach rtrActiveObj $routers {

                             ::L2::Verify::MgmtCommand -cmd "::L1::ServiceShutdown" \
                                       -params [list   -rtrObj  $rtrActiveObj \
                                                       -service [::Const::SERVICE_MSG_BACKBONE] \
                                                       -action  [::Const::CFG_REMOVE] ]
                         }
                     }
               } "haFailoverOne"   {
                     set haClusterObj [lindex [lshuffle $haClusterObjList $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $haClusterObj"
                     $haClusterObj RedundancySwitchover [::Const::TRUE]
                     foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                        ::L2::Verify::Redundancy \
                             -rtrObj           $rtr \
                             -redundancyStatus "Up"
                     }
                     sleep $sleepInAction
               } "haFailoverAll"   {
                     foreach haClusterObj $haClusterObjList {
                         $haClusterObj RedundancySwitchover [::Const::TRUE]
                     }
                     foreach haClusterObj $haClusterObjList {
                         foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                            ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $rtr"
                            ::L2::Verify::Redundancy \
                                 -rtrObj           $rtr \
                                 -redundancyStatus "Up"
                         }
                     }
                     sleep $sleepInAction
               } "replicationSwitchoverOne"   {
                     foreach haClusterObj [lindex [lshuffle $haClusterObjList $randomizeActionTarget $seed] 0] {
                         if {[$haClusterObj GetRepPrimary] != ""} {
                             break
                         }
                     }
                     set msgVpn [lindex [lshuffle $msgVpnList $randomizeActionTarget $seed] 0]

                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $haClusterObj msgVpn $msgVpn"
                     ::L1::SysTest::ReplicationSwitchover \
                            -haClusterObj $haClusterObj \
                            -msgVpnList $msgVpn

                     set skipTempEndpointCheck 1
                     sleep $sleepInAction
               } "replicationSwitchoverAll"   {
                     foreach haClusterObj [lindex [lshuffle $haClusterObjList $randomizeActionTarget $seed] 0] {
                         if {[$haClusterObj GetRepPrimary] != ""} {
                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $haClusterObj msgVpn $msgVpnList"
                             ::L1::SysTest::ReplicationSwitchover \
                                    -haClusterObj $haClusterObj \
                                    -msgVpnList $msgVpnList
                         }
                     }
                     set skipTempEndpointCheck 1
                     sleep $sleepInAction
               } "clusterDisableEnableOne"   {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj"
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterShutdown" \
                                                 -params [list -action      [::Const::CFG_ADD] \
                                                               -rtrObj      $rtrActiveObj \
                                                               -clusterName $CLUSTER_NAME]
                     ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                           -name $CLUSTER_NAME \
                                           -oper-up "false" \
                                           -oper-fail-reason "Cluster Disabled"
                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterShutdown" \
                                                 -params [list -action      [::Const::CFG_REMOVE] \
                                                               -rtrObj      $rtrActiveObj \
                                                               -clusterName $CLUSTER_NAME]
               } "clusterDisableEnableAll"   {
                    foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                        set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                        set routers [keylget dmrCluster STANDALONE_NODES]
                        foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                            lappend routers [getActive $ha]
                        }
                        ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                        foreach rtrActiveObj $routers {
                            ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterShutdown" \
                                                        -params [list -action      [::Const::CFG_ADD] \
                                                                      -rtrObj      $rtrActiveObj \
                                                                      -clusterName $CLUSTER_NAME]
                            ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                                  -name $CLUSTER_NAME \
                                                  -oper-up "false" \
                                                  -oper-fail-reason "Cluster Disabled"
                        }
                    }
                    sleep $sleepInAction
                    foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {
                             ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterShutdown" \
                                                         -params [list -action      [::Const::CFG_REMOVE] \
                                                                       -rtrObj      $rtrActiveObj \
                                                                       -clusterName $CLUSTER_NAME]
                         }
                     }
               } "clusterDeleteReAddOne"   {
                     # set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     # ::L3::DeleteCluster -clusterData $dmrCluster
                     # sleep $sleepInAction
               } "clusterDeleteReAddAll"   {
                     ::L1::Test::ActionStart "action $actionNum - Delete the re-add all clusters"
                     foreach CLUSTER [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         ::L3::DeleteCluster -clusterData $CLUSTER
                     }
                     sleep $sleepInAction

                     set CLUSTER_A [::L3::Clustering \
                                   -rtrObjList               [lrange $haClusterObjList 0 2] \
                                   -clusterNamePrefix        "CLUSTER_1" \
                                   -transport                "ssl-compressed" \
                                   -span                     "internal" \
                                   -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
                                   -basicAuthType            [::Const::AUTH_TYPE_NONE] \
                                   -useLinkAuthentication    [::Const::TRUE] \
                                   -useInitiatorLexical      [::Const::FALSE] \
                                   -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
                                   -clusterPassword          "" \
                                   -useFqdn                  $connectViaUseFqdn \
                                   -trustedCommonName        $CERT_CN \
                                   -msgVpnList               $msgVpnList ]

                     foreach haClusterObj [lrange $haClusterObjList 0 2] {
                         foreach rtrObj "[getPrimary $haClusterObj] [getRepPrimary $haClusterObj]" {
                             if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
                                 ::L2::ClusterAuthenticationCertMatchingRule \
                                         -rtrObj          $rtrObj \
                                         -clusterName     [keylget CLUSTER_A [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                                         -ruleName        "afw" \
                                         -shutdown        [::Const::FALSE]
                             }
                         }
                     }

                     set CLUSTER_B [::L3::Clustering \
                                   -rtrObjList               [lrange $haClusterObjList 3 4] \
                                   -clusterNamePrefix        "CLUSTER_2" \
                                   -transport                "ssl-compressed" \
                                   -span                     "internal" \
                                   -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
                                   -basicAuthType            [::Const::AUTH_TYPE_NONE] \
                                   -useLinkAuthentication    [::Const::TRUE] \
                                   -useInitiatorLexical      [::Const::FALSE] \
                                   -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
                                   -clusterPassword          "" \
                                   -useFqdn                  $connectViaUseFqdn \
                                   -trustedCommonName        $CERT_CN \
                                   -msgVpnList               $msgVpnList ]

                     foreach haClusterObj [lrange $haClusterObjList 3 4] {
                         foreach rtrObj "[getPrimary $haClusterObj] [getRepPrimary $haClusterObj]" {
                             if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
                                 ::L2::ClusterAuthenticationCertMatchingRule \
                                         -rtrObj          $rtrObj \
                                         -clusterName     [keylget CLUSTER_B [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                                         -ruleName        "afw" \
                                         -shutdown        [::Const::FALSE]
                             }
                         }
                     }

                     set CLUSTER_C [::L3::Clustering \
                                   -rtrObjList               [lrange $standaloneObjList 0 1] \
                                   -clusterNamePrefix        "CLUSTiER_3" \
                                   -transport                "ssl-compressed" \
                                   -span                     "internal" \
                                   -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
                                   -basicAuthType            [::Const::AUTH_TYPE_NONE] \
                                   -useLinkAuthentication    [::Const::TRUE] \
                                   -useInitiatorLexical      [::Const::FALSE] \
                                   -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
                                   -clusterPassword          "" \
                                   -useFqdn                  $connectViaUseFqdn \
                                   -trustedCommonName        $CERT_CN \
                                   -msgVpnList               $msgVpnList ]

                     foreach rtrObj [lrange $standaloneObjList 0 1] {
                         if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
                             ::L2::ClusterAuthenticationCertMatchingRule \
                                     -rtrObj          $rtrObj \
                                     -clusterName     [keylget CLUSTER_C [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                                     -ruleName        "afw" \
                                     -shutdown        [::Const::FALSE]
                         }
                     }

                     set CLUSTER_D [::L3::Clustering \
                                   -rtrObjList               [lrange $standaloneObjList 2 3] \
                                   -clusterNamePrefix        "CLUSTER_4" \
                                   -transport                "ssl-compressed" \
                                   -span                     "internal" \
                                   -authScheme               [::Const::AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE] \
                                   -basicAuthType            [::Const::AUTH_TYPE_NONE] \
                                   -useLinkAuthentication    [::Const::TRUE] \
                                   -useInitiatorLexical      [::Const::FALSE] \
                                   -clusterCertifFile        [::Const::BRIDGE_CLIENT_CERT_PEM_FILE] \
                                   -clusterPassword          "" \
                                   -trustedCommonName        $CERT_CN \
                                   -useFqdn                  $connectViaUseFqdn \
                                   -msgVpnList               $msgVpnList ]

                     foreach rtrObj [lrange $standaloneObjList 2 3] {
                         if {[$rtrObj IsCapable [::RtrProp::CAP_DMR_CLIENT_CERT_MATCHING]] == [::Const::TRUE]} {
                             ::L2::ClusterAuthenticationCertMatchingRule \
                                     -rtrObj          $rtrObj \
                                     -clusterName     [keylget CLUSTER_D [::L1::Rtr::GetRouterName $rtrObj].NAME] \
                                     -ruleName        "afw" \
                                     -shutdown        [::Const::FALSE]
                         }
                     }

                     ::L3::InterconnectClusters \
                                   -cluster1Data          $CLUSTER_A \
                                   -cluster2Data          $CLUSTER_B \
                                   -msgVpnList            "allCommon" \
                                   -gatewayTypeCluster1   "dr_Ha" \
                                   -gatewayTypeCluster2   "dr_Ha" \
                                   -useNewGatewayCluster1 [::Const::TRUE] \
                                   -useNewGatewayCluster2 [::Const::TRUE] \
                                   -connectViaUseFqdn        $connectViaUseFqdn \
                                   -useInitiatorLexical   [::Const::FALSE] \
                                   -linkTransport         "ssl-compressed"
                     ::L3::InterconnectClusters \
                                   -cluster1Data          $CLUSTER_A \
                                   -cluster2Data          $CLUSTER_D \
                                   -msgVpnList            "allCommon" \
                                   -gatewayTypeCluster1   "dr_Ha" \
                                   -gatewayTypeCluster2   "standalone" \
                                   -useNewGatewayCluster1 [::Const::TRUE] \
                                   -useNewGatewayCluster2 [::Const::TRUE] \
                                   -connectViaUseFqdn        $connectViaUseFqdn \
                                   -useInitiatorLexical   [::Const::FALSE] \
                                   -linkTransport         "ssl-compressed"
                     ::L3::InterconnectClusters \
                                   -cluster1Data          $CLUSTER_B \
                                   -cluster2Data          $CLUSTER_D \
                                   -msgVpnList            "allCommon" \
                                   -gatewayTypeCluster1   "dr_Ha" \
                                   -gatewayTypeCluster2   "standalone" \
                                   -useNewGatewayCluster1 [::Const::TRUE] \
                                   -useNewGatewayCluster2 [::Const::TRUE] \
                                   -connectViaUseFqdn        $connectViaUseFqdn \
                                   -useInitiatorLexical   [::Const::FALSE] \
                                   -linkTransport         "ssl-compressed"
               } "dmrMsgVpnDisableEnableOne"   {
                     set msgVpn [lindex [lshuffle $msgVpnList $randomizeActionTarget $seed] 0]
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [$ha GetAdActiveRepActive $msgVpn]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj msg-vpn $msgVpn"
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::MessageVpnClusterShutdown" \
                                                 -params [list -action [::Const::CFG_ADD] \
                                                               -rtrObj $rtrActiveObj \
                                                               -msgVpn $msgVpn]
                     if {$useClusterShowCmds == [::Const::TRUE]} {
                         ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                               -name $CLUSTER_NAME \
                                               -oper-up "true"
                     }
                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::MessageVpnClusterShutdown" \
                                                 -params [list -action [::Const::CFG_REMOVE] \
                                                               -rtrObj $rtrActiveObj \
                                                               -msgVpn $msgVpn]
                     sleep [expr 30 + 6 * $sleepInAction]
               } "dmrMsgVpnDisableEnableAll"   {
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             foreach msgVpn $msgVpnList {
                                 lappend routers [$ha GetAdActiveRepActive $msgVpn]
                             }
                         }
                         set routers [lsort -unique $routers]
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {
                             foreach msgVpn $msgVpnList {
                                 ::L2::Verify::MgmtCommand   -cmd     "::L1::MessageVpnClusterShutdown" \
                                                             -params [list -action [::Const::CFG_ADD] \
                                                                           -rtrObj $rtrActiveObj \
                                                                           -msgVpn $msgVpn]
                              }
                         }
                     }
                     sleep $sleepInAction
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             foreach msgVpn $msgVpnList {
                                 lappend routers [$ha GetAdActiveRepActive $msgVpn]
                             }
                         }
                         set routers [lsort -unique $routers]
                         foreach rtrActiveObj $routers {
                             foreach msgVpn $msgVpnList {
                                 ::L2::Verify::MgmtCommand   -cmd     "::L1::MessageVpnClusterShutdown" \
                                                             -params [list -action [::Const::CFG_REMOVE] \
                                                                           -rtrObj $rtrActiveObj \
                                                                           -msgVpn $msgVpn]
                              }
                         }
                     }
                     sleep [expr 30 + 6 * $sleepInAction]
               } "linkDisableEnableOne"   {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     set lnkList [list]
                     set retKList [::L1::Show::ClusterLink \
                            -rtrObj    $rtrActiveObj \
                            -cluster-name $CLUSTER_NAME \
                            -link-name  *]
                     set domObj [[keylget retKList "domObj"] documentElement]
                     set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                     foreach lnk $l {
                         lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                     }
                     set link [lindex [lshuffle [ldiff $lnkList "#ACTIVE"] $randomizeActionTarget $seed] 0]

                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj link $link"

                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                 -params [list -action [::Const::CFG_ADD] \
                                                               -rtrObj $rtrActiveObj \
                                                               -clusterLinkName  nk\
                                                               -clusterName $CLUSTER_NAME]

                     ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                           -name $CLUSTER_NAME \
                                           -oper-up "false" \
                                           -oper-fail-reason "Link(s) Down"

                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                   -params [list -action [::Const::CFG_REMOVE] \
                                                             -rtrObj $rtrActiveObj \
                                                               -clusterLinkName $link \
                                                               -clusterName $CLUSTER_NAME]
               } "linkDisableEnableAll"   {
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                         set lnkList [list]
                         set retKList [::L1::Show::ClusterLink \
                                -rtrObj    $rtrActiveObj \
                                -cluster-name $CLUSTER_NAME \
                                -link-name  *]
                         set domObj [[keylget retKList "domObj"] documentElement]
                         set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                         foreach lnk $l {
                             lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                         }
                         foreach link $lnkList {
                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj link $link"

                             ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                         -params [list -action [::Const::CFG_ADD] \
                                                                       -rtrObj $rtrActiveObj \
                                                                       -clusterLinkName  $link\
                                                                       -clusterName $CLUSTER_NAME]
                         }
                         ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                               -name $CLUSTER_NAME \
                                               -oper-up "false" \
                                               -oper-fail-reason "Link(s) Down"

                     }
                     sleep $sleepInAction
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                         set lnkList [list]
                         set retKList [::L1::Show::ClusterLink \
                                -rtrObj    $rtrActiveObj \
                                -cluster-name $CLUSTER_NAME \
                                -link-name  *]
                         set domObj [[keylget retKList "domObj"] documentElement]
                         set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                         foreach lnk $l {
                             lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                         }
                         foreach link $lnkList {
                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj link $link"

                             ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                         -params [list -action [::Const::CFG_REMOVE] \
                                                                       -rtrObj $rtrActiveObj \
                                                                       -clusterLinkName  $link\
                                                                       -clusterName $CLUSTER_NAME]
                         }
                     }
               } "activeLinkDisableEnableOne"   {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj"
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                 -params [list -action [::Const::CFG_ADD] \
                                                               -rtrObj $rtrActiveObj \
                                                               -clusterLinkName "#ACTIVE" \
                                                               -clusterName $CLUSTER_NAME]
                     ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                           -name $CLUSTER_NAME \
                                           -oper-up "false" \
                                           -oper-fail-reason "Link(s) Down"

                     sleep $sleepInAction
                     ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                   -params [list -action [::Const::CFG_REMOVE] \
                                                             -rtrObj $rtrActiveObj \
                                                               -clusterLinkName "#ACTIVE" \
                                                               -clusterName $CLUSTER_NAME]
               } "activeLinkDisableEnableAll"  {
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"
                         foreach rtrActiveObj $routers {
                             ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                         -params [list -action [::Const::CFG_ADD] \
                                                                       -rtrObj $rtrActiveObj \
                                                                       -clusterLinkName "#ACTIVE" \
                                                                   -clusterName $CLUSTER_NAME]
                             ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                                   -name $CLUSTER_NAME \
                                                   -oper-up "false" \
                                                   -oper-fail-reason "Link(s) Down"
                         }
                     }
                     sleep $sleepInAction
                     foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         foreach rtrActiveObj $routers {
                             ::L2::Verify::MgmtCommand   -cmd     "::L1::ClusterLinkShutdown" \
                                                       -params [list -action [::Const::CFG_REMOVE] \
                                                                 -rtrObj $rtrActiveObj \
                                                                   -clusterLinkName "#ACTIVE" \
                                                                   -clusterName $CLUSTER_NAME]
                          }
                     }
               } "linkDeleteReAddOne"   {
                     set dmrCluster [lindex [lshuffle [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] $randomizeActionTarget [expr $ACTION_NUMBER * $seed]] 0]
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                     set lnkList [list]
                     set retKList [::L1::Show::ClusterLink \
                            -rtrObj    $rtrActiveObj \
                            -cluster-name $CLUSTER_NAME \
                            -link-name  *]
                     set domObj [[keylget retKList "domObj"] documentElement]
                     set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                     foreach lnk $l {
                         lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                     }
                     set link [lindex [lshuffle [ldiff $lnkList "#ACTIVE"] $randomizeActionTarget $seed] 0]

                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj link $link"

                     set span              [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.SPAN]
                     set transport         [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.TRANSPORT]
                     set connectViaList    [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.CONNECTVIAS]
                     set initiator         [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.INITIATOR]
                     set password          [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.LINK_PASSWORD]
                     set trustedCommonName [keylget MYCLUSTER TRUSTED_COMMON_NAME]
                     set authScheme        [keylget MYCLUSTER AUTH_SCHEME]

                     ::L2::ClusterLink \
                                    -action             [::Const::CFG_REMOVE] \
                                    -rtrObj             $rtrActiveObj \
                                    -clusterName        $CLUSTER_NAME \
                                    -clusterLinkName    $link

                     sleep $sleepInAction
                     ::L2::ClusterLink \
                                     -action             [::Const::CFG_ADD] \
                                     -rtrObj             $rtrActiveObj \
                                     -clusterName        $CLUSTER_NAME \
                                     -clusterLinkName    $link \
                                     -transport          $transport \
                                     -initiator          $initiator \
                                     -span               $span \
                                     -connectViaList     $connectViaList \
                                     -authScheme         $authScheme \
                                     -password           $password \
                                     -trustedCommonName  $trustedCommonName

               } "linkDeleteReAddAll"   {
                     foreach  dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                         set lnkList [list]
                         set retKList [::L1::Show::ClusterLink \
                                -rtrObj    $rtrActiveObj \
                                -cluster-name $CLUSTER_NAME \
                                -link-name  *]
                         set domObj [[keylget retKList "domObj"] documentElement]
                         set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                         foreach lnk $l {
                             lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                         }
                         foreach link [ldiff $lnkList "#ACTIVE"] {

                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME target $rtrActiveObj link $link"

                             set _span($rtrActiveObj,$link)              [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.SPAN]
                             set _transport($rtrActiveObj,$link)         [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.TRANSPORT]
                             set _connectViaList($rtrActiveObj,$link)    [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.CONNECTVIAS]
                             set _initiator($rtrActiveObj,$link)         [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.INITIATOR]
                             set _password($rtrActiveObj,$link)          [keylget MYCLUSTER [::L1::Rtr::GetRouterName $rtrActiveObj].$link.LINK_PASSWORD]
                             set _trustedCommonName($rtrActiveObj,$link) [keylget MYCLUSTER TRUSTED_COMMON_NAME]
                             set _authScheme($rtrActiveObj,$link)        [keylget MYCLUSTER AUTH_SCHEME]

                             ::L2::ClusterLink \
                                            -action             [::Const::CFG_REMOVE] \
                                            -rtrObj             $rtrActiveObj \
                                            -clusterName        $CLUSTER_NAME \
                                            -clusterLinkName    $link
                         }
                     }

                     sleep $sleepInAction

                     foreach  dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                         set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                         set routers [keylget dmrCluster STANDALONE_NODES]
                         foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                             lappend routers [getActive $ha]
                         }
                         set rtrActiveObj [lindex [lshuffle $routers $randomizeActionTarget $seed] 0]
                         set lnkList [list]
                         set retKList [::L1::Show::ClusterLink \
                                -rtrObj    $rtrActiveObj \
                                -cluster-name $CLUSTER_NAME \
                                -link-name  *]
                         set domObj [[keylget retKList "domObj"] documentElement]
                         set l [$domObj selectNodes "//cluster/clusters/cluster/links/link"]
                         foreach lnk $l {
                             lappend lnkList [::SolDom::GetElementTextFromNode $lnk "remote-node-name"]
                         }
                         foreach link $lnkList {

                             ::L2::ClusterLink \
                                             -action             [::Const::CFG_ADD] \
                                             -rtrObj             $rtrActiveObj \
                                             -clusterName        $CLUSTER_NAME \
                                             -clusterLinkName    $link \
                                             -transport          $_transport($rtrActiveObj,$link) \
                                             -initiator          $_initiator($rtrActiveObj,$link) \
                                             -span               $_span($rtrActiveObj,$link) \
                                             -connectViaList     $_connectViaList($rtrActiveObj,$link) \
                                             -authScheme         $_authScheme($rtrActiveObj,$link) \
                                             -password           $_password($rtrActiveObj,$link) \
                                             -trustedCommonName  $_trustedCommonName($rtrActiveObj,$link)
                         }
                     }
               } "upgrade"   {
                     set destLoad     [join soltr_$destLoad]
                     foreach haClusterObj $haClusterObjList {
                         set primaryNode  [$haClusterObj GetPrimary]
                         set repPrimary   [$haClusterObj GetRepPrimary]
                         set backupNode   [$haClusterObj GetBackup]
                         set repBackup    [$haClusterObj GetRepBackup]
                         set monitorNode  [$haClusterObj GetMonitor]
                         set repMonitor   [$haClusterObj GetRepMonitor]
                         if {![$primaryNode IsVMR]} {
                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $repPrimary $repBackup"

                             ::L3::Upgrade::UpgradeAdRedundantInService \
                                         -rtrObj               $primaryNode \
                                         -rtrObjRedun          $backupNode \
                                         -destLoad             $destLoad

                             foreach _node $dmrNodeList {
                                 ::L2::Verify::Cluster -rtrObj [getActive $_node] \
                                                       -name [keylget MYCLUSTER [::L1::Rtr::GetRouterName [getPrimary $_node]].NAME] \
                                                       -timeout 300000 \
                                                       -topology-issue-count 0 \
                                                       -oper-up "true"
                             }
                         } else {
                             ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $repPrimary $repBackup $monitorNode"

                             ::L3::Upgrade::UpgradeIssuVmrRedundant \
                                         -rtrObj               $primaryNode \
                                         -rtrObjRedun          $backupNode \
                                         -rtrObjMonitoring     $monitorNode \
                                         -destLoad             $destLoad \
                                         -destPlatform         $upgradeEdition

                             foreach _node $dmrNodeList {
                                 ::L2::Verify::Cluster -rtrObj [getActive $_node] \
                                                       -name [keylget MYCLUSTER [::L1::Rtr::GetRouterName [getPrimary $_node]].NAME] \
                                                       -timeout 300000 \
                                                       -topology-issue-count 0 \
                                                       -oper-up "true"
                             }
                         }

                         if {$repPrimary != ""} {
                             if {![$repPrimary IsVMR]} {

                                 ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $repPrimary $repBackup"


                                 ::L3::Upgrade::UpgradeAdRedundantInService \
                                             -rtrObj               $repPrimary \
                                             -rtrObjRedun          $repBackup \
                                             -destLoad             $destLoad

                                 foreach _node $dmrNodeList {
                                     ::L2::Verify::Cluster -rtrObj [getActive $_node] \
                                                           -name [keylget MYCLUSTER [::L1::Rtr::GetRouterName [getPrimary $_node]].NAME] \
                                                           -timeout 300000 \
                                                           -topology-issue-count 0 \
                                                           -oper-up "true"
                                 }
                             } else {

                                 ::L3::Upgrade::UpgradeIssuVmrRedundant \
                                             -rtrObj               $repPrimary \
                                             -rtrObjRedun          $repBackup \
                                             -rtrObjMonitoring     $repMonitor \
                                             -destLoad             $destLoad \
                                             -destPlatform         $upgradeEdition

                                 foreach _node $dmrNodeList {
                                     ::L2::Verify::Cluster -rtrObj [getActive $_node] \
                                                           -name [keylget MYCLUSTER [::L1::Rtr::GetRouterName [getPrimary $_node]].NAME] \
                                                           -timeout 300000 \
                                                           -topology-issue-count 0 \
                                                           -oper-up "true"
                                 }
                             }
                         }
                     }
                     foreach rtrObj $standaloneObjList {
                         ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action target $rtrObj"

                         ::L3::Upgrade::UpgradeAdStandalone \
                                 -rtrObj               "$rtrObj" \
                                 -destLoad             "$destLoad"

                         foreach _node $dmrNodeList {
                             ::L2::Verify::Cluster -rtrObj [getActive $_node] \
                                                   -name [keylget MYCLUSTER [::L1::Rtr::GetRouterName [getPrimary $_node]].NAME] \
                                                   -timeout 300000 \
                                                   -topology-issue-count 0 \
                                                   -oper-up "true"
                         }
                     }
                 }
            }; # end of switch action 

            if {$useClusterShowCmds == [::Const::TRUE]} {

                 foreach dmrCluster [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
                     set CLUSTER_NAME [keylget dmrCluster [lindex [lindex $dmrCluster 0] 0].NAME]
                     set routers [keylget dmrCluster STANDALONE_NODES]
                     foreach ha [keylget dmrCluster REDUNDANT_NODES] {
                         lappend routers [getActive $ha]
                     }
                     ::L1::Test::Result [::Const::LOG_RESULTS_INFO] "action $action cluster $CLUSTER_NAME"

                     foreach rtrActiveObj $routers {

                        ::L2::Verify::Cluster -rtrObj $rtrActiveObj \
                                                      -name $CLUSTER_NAME \
                                                      -timeout 900000 \
                                                      -oper-up "true" 
                    }
                }
            }
            ::L1::Test::ActionEnd
            #################################################################################################
            incr actionNum
            ::L1::Test::ActionStart "$actionNum - \
                                     Wait for subscription propagation after action \
                                     ${ACTION_NUMBER}/[llength $actionList] $action"

            sleep 180
            ::L1::Test::ActionEnd
            ##########################################################################################################
            # check stats of the traffic during action
            if {[lsearch $actionListWithTraffic $action] != "-1"} {

                incr actionNum
                ::L1::Test::ActionStart "$actionNum - Stop publishers of traffic during action ${ACTION_NUMBER}/[llength $actionList] $action"

                foreach msgVpn $msgVpnList {
                    foreach case $caseList {
                        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
                            ::L2::Client::WaitUntilDonePublishing \
                                  -clientObj        $pubObj($msgVpn,$case,$c) \
                                  -waitTime         0 \
                                  -failLevel [::Const::LOG_RESULTS_INFO]
                            ::L2::Client::StopPublishing \
                                     -clientObj $pubObj($msgVpn,$case,$c) \
                                     -failLevel [::Const::LOG_RESULTS_INFO]
                        }
                    }
                }
                sleep 10
                ::L1::Test::ActionEnd
                #############################################################################################################################
                incr actionNum
                ::L1::Test::ActionStart "$actionNum - Wait for all #cluster queues to drain during action ${ACTION_NUMBER}/[llength $actionList] $action"
                foreach msgVpn $msgVpnList {
                    foreach dmrNode $dmrNodeList {

                        set retKList [::L1::Show::Queue \
                                          -rtrObj [getActive $dmrNode] \
                                          -name "#cluster:*"\
                                          -msgVpn $msgVpn ]

                        set domObj [[keylget retKList "domObj"] documentElement]
                        set qNodes [$domObj selectNodes "//queues/queue"]
    
                        foreach qNode $qNodes {

                            set qName [::SolDom::GetElementTextFromNode $qNode "name"]
                            if {$qName != ""} {
                                ::L2::Verify::Queue \
                                      -rtrObj [getActive $dmrNode] \
                                      -msgVpn $msgVpn \
                                      -name $qName \
                                      -timeout $QUEUE_DRAIN_WAIT_TIME \
                                      -numMessagesSpooled 0

                            }
                        }
                    }
                }
                ::L1::Test::ActionEnd
                ##########################################################################################################
                incr actionNum
                ::L1::Test::ActionStart "$actionNum - Checking stats of traffic during action ${ACTION_NUMBER}/[llength $actionList] $action"

                foreach msgVpn $msgVpnList {
                    foreach case $caseList {
                        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

                            if {($case == "TQE" || $case == "TTE") && ($skipTempEndpointCheck == 1) } { continue }

                            set _txStatsKList [::L1::Client::GetStats -clientObj $pubObj($msgVpn,$case,$c)]
                            set tx [keylget _txStatsKList [::Const::STAT_TX_MSGS]]
                            ::L1::Client::ResetStats $pubObj($msgVpn,$case,$c)

                            set _rxStatsKList [::L1::Client::GetStats -clientObj $subObj($msgVpn,$case,$c)]
                            set rx [keylget _rxStatsKList [::Const::STAT_RX_MSGS]]
                            ::L1::Client::ResetStats $subObj($msgVpn,$case,$c)

                            if {($msgType($case) == [::Const::MSG_TYPE_PERSISTENT]) && ($rx < $tx) && ($case != "DEMOTE")} {
                               ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                                        "stats of traffic during action ${ACTION_NUMBER}/[llength $actionList] $action \
                                         message-vpn $msgVpn case $case client $c\
                                         $msgType($case) $testTopicList($case,$c)\
                                         pub: $pubObj($msgVpn,$case,$c) Tx= $tx \
                                         sub: $subObj($msgVpn,$case,$c) Rx= $rx \
                                         (delta= [expr $tx - $rx])"
                            } elseif {$rx == 0} {
                               ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                                        "stats of traffic during action ${ACTION_NUMBER}/[llength $actionList] $action \
                                         message-vpn $msgVpn case $case client $c\
                                         $msgType($case) $testTopicList($case,$c)\
                                         pub: $pubObj($msgVpn,$case,$c) Tx= $tx \
                                         sub: $subObj($msgVpn,$case,$c) Rx= $rx \
                                         (delta= [expr $tx - $rx])"
                            }
                        }
                    }
                    ::L1::Test::ActionEnd
            }
            #############################################################################################################
            incr actionNum
            ::L1::Test::ActionStart "$actionNum - Start publishers after action ${ACTION_NUMBER}/[llength $actionList] $action"
            sleep 15
            foreach msgVpn $msgVpnList {
                foreach case $caseList {
                    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
   
                        if {[string match replicationSwitchover* $action] && $case == "TQE"} {continue}

                        ::L2::Client::StartPublishing \
                              -clientObj        $pubObj($msgVpn,$case,$c) \
                              -numMsgs          $NUM_MSGS_ACTION \
                              -topicsList       $testTopicList($case,$c) \
                              -attachSizeList   100 \
                              -rateInMsgsPerSec $PUB_RATE \
                              -msgType          $msgType($case) 
                    } 
                } 
            } 
            ::L1::Test::ActionEnd
            sleep 10
            ####################################################################################################
            incr actionNum
            ::L1::Test::ActionStart "$actionNum - Stop publishers after action ${ACTION_NUMBER}/[llength $actionList] $action"
            foreach msgVpn $msgVpnList {
                foreach case $caseList {
                    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

                        ::L2::Client::WaitUntilDonePublishing \
                              -clientObj        $pubObj($msgVpn,$case,$c) \
                              -waitTime         $PUB_WAIT_TIME \
                              -failLevel [::Const::LOG_RESULTS_INFO]
                        ::L2::Client::StopPublishing \
                              -clientObj $pubObj($msgVpn,$case,$c) \
                              -failLevel [::Const::LOG_RESULTS_INFO]
                    }
                }
            }
            ::L1::Test::ActionEnd
            #############################################################################################################################
            incr actionNum
            ::L1::Test::ActionStart "$actionNum - Wait for all #cluster queues to drain after action ${ACTION_NUMBER}/[llength $actionList] $action"
            foreach msgVpn $msgVpnList {
                foreach dmrNode $dmrNodeList {

                    set retKList [::L1::Show::Queue \
                                      -rtrObj [getActive $dmrNode] \
                                      -name "#cluster:*"\
                                      -msgVpn $msgVpn ]

                    set domObj [[keylget retKList "domObj"] documentElement]
                    set qNodes [$domObj selectNodes "//queues/queue"]

                    foreach qNode $qNodes {

                        set qName [::SolDom::GetElementTextFromNode $qNode "name"]
                        if {$qName != ""} {
                            ::L2::Verify::Queue \
                                  -rtrObj [getActive $dmrNode] \
                                  -msgVpn $msgVpn \
                                  -name $qName \
                                  -timeout $QUEUE_DRAIN_WAIT_TIME \
                                  -numMessagesSpooled 0

                        }
                    }
                }
            }
            ::L1::Test::ActionEnd
            ####################################################################################################
            incr actionNum
            ::L1::Test::ActionStart "$actionNum - Check client stats \
                                     after action ${ACTION_NUMBER}/[llength $actionList] $action"

            foreach msgVpn $msgVpnList {
                foreach case $caseList {
                    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

                        if {($case == "TQE" || $case == "TTE") && ($skipTempEndpointCheck == 1) } { continue }

                        set _txStatsKList [::L1::Client::GetStats -clientObj $pubObj($msgVpn,$case,$c)]

                        if {[string match replicationSwitchover* $action] && $case == "TQE"} {continue}

                        set tx [keylget _txStatsKList [::Const::STAT_TX_MSGS]]
                        ::L1::Client::ResetStats $pubObj($msgVpn,$case,$c)

                        set _rxStatsKList [::L1::Client::GetStats -clientObj $subObj($msgVpn,$case,$c)]
                        set rx [keylget _rxStatsKList [::Const::STAT_RX_MSGS]]
                        ::L1::Client::ResetStats $subObj($msgVpn,$case,$c)

                        if {($msgType($case) == [::Const::MSG_TYPE_PERSISTENT]) && ($rx < $tx)} {
                           ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                                                "after action ${ACTION_NUMBER}/[llength $actionList] $action \
                                                 case: $case, clien=nt $c, msgVpn: $msgVpn, \
                                                 pub: $msgType($case) on $node(PUB,$msgVpn,$case,$c) \
                                                 to topic:$testTopicList($case,$c), \
                                                 sub on $node(SUB,$msgVpn,$case,$c), \
                                                 pub/sub: Rx= $rx, Tx= $tx (delta= [expr $tx - $rx])"
                        } elseif {$rx < [expr $tx/2]} {
                           ::L1::Test::Result [::Const::LOG_RESULTS_FAIL] \
                                                "after action ${ACTION_NUMBER}/[llength $actionList] $action \
                                                 case: $case, client $c, msgVpn: $msgVpn, \
                                                 pub: $msgType($case) on $node(PUB,$msgVpn,$case,$c) \
                                                 to topic:$testTopicList($case,$c), \
                                                 sub on $node(SUB,$msgVpn,$case,$c), \
                                                 pub/sub: Rx= $rx, Tx= $tx (delta= [expr $tx - $rx])"
                        }
                    }
                }
            }; # end of check stats after action
            ::L1::Test::ActionEnd

            # switch back
            if {$action == "haFailoverOne" || $action == "reloadActiveOne"}  {
                incr actionNum
                ::L1::Test::ActionStart "$actionNum - HA revert after $action"
                 $haClusterObj RedundancySwitchover [::Const::TRUE]
                  foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                     ::L2::Verify::Redundancy \
                          -rtrObj           $rtr \
                          -redundancyStatus "Up" 
                  }
                 ::L1::Test::ActionEnd
            }
            if {$action == "haFailoverAll" || $action == "reloadActiveAll"}  {
                ::L1::Test::ActionStart "$actionNum - HA revert all after $action"
                 foreach haClusterObj $haClusterObjList {
                     $haClusterObj RedundancySwitchover [::Const::TRUE]
                 }
                 foreach haClusterObj $haClusterObjList {
                     foreach rtr [list [$haClusterObj GetPrimary] [$haClusterObj GetBackup]] {
                        ::L2::Verify::Redundancy \
                             -rtrObj           $rtr \
                             -redundancyStatus "Up" 
                     }
                }
                ::L1::Test::ActionEnd
            }
    }
} ; # end of action

############################################################################################
# Test Cleanup
############################################################################################

#############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the clusters"
foreach CLUSTER [list $CLUSTER_A $CLUSTER_B $CLUSTER_C $CLUSTER_D] {
    ::L3::DeleteCluster -clusterData $CLUSTER
}
::L1::Test::ActionEnd
#############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the bridges"
foreach msgVpn $msgVpnList {

    foreach rtrObj [list [$selectedNode_A GetPrimary]  \
                          $selectedNode_C] {

        ::L2::Bridge     -rtrObj         $rtrObj \
                         -name           $BRIDGE_NAME \
                         -msgVpn         $msgVpn \
                         -action         [::Const::CFG_REMOVE]

        ::L2::Queue      -rtrObj         $rtrObj \
                         -msgVpn         $msgVpn \
                         -name           $BRIDGE_QUEUE_NAME \
                         -action         [::Const::CFG_REMOVE]
    }
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the clients"
foreach msgVpn $msgVpnList {
    for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {
        if {[lsearch $caseList "TTE"] != "-1"} {
            ::L2::Client::TopicUpdate   -clientObj  $subObj($msgVpn,TTE,$c) \
                                        -addFlag    [::Const::FALSE] \
                                        -teList     $tte($msgVpn,$c)
        }
        if {[lsearch $caseList "TQE"] != "-1"} {
            ::L2::Client::QueueUpdate   -clientObj $subObj($msgVpn,TQE,$c) \
                                        -addFlag    [::Const::FALSE] \
                                        -queueList  $tqe($msgVpn,$c)
        }    
    }    
}
foreach clientObj $clientList {
    ::L2::Client::Delete \
           -clientObj     $clientObj
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the replicated topics"
foreach msgVpn $msgVpnList {
    foreach case "QUEUE TOPIC_ON_QUEUE PROMOTE" {
        for {set c 1} {$c <= $numClientsPerCase} {incr c +1} {

            if {[lsearch $caseList $case] != "-1"} {
                set myQueue($case,$c) "${QUEUE_PREFIX}_${c}_${case}"

                set rtrListToConfigure [list]
                set _node $node(SUB,$msgVpn,$case,$c)
                if {[$_node info class] == "::HACluster"} {
                    lappend rtrListToConfigure [$_node GetPrimary]
                } else {
                    lappend rtrListToConfigure $_node
                }
                foreach router $rtrListToConfigure {

                    if {([::L1::Rtr::IsCapable [::RtrProp::CAP_DMR_REPLICATION]] == [::Const::TRUE]) && \
                        ($drSetups != 0)} {
                            ::L2::VpnReplicationTopic \
                                 -rtrObj              $router \
                                  -msgVpn             $msgVpn \
                                  -asyncTopics        $testTopicList($case,$c) \
                                  -action             [::Const::CFG_REMOVE]
                    }

                }
            }
        }
    }
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the endpoints"
foreach msgVpn $msgVpnList {
    foreach dmrNode $dmrNodeList {

        set rObj [getActive $dmrNode]

        set retK_Q_List [::L1::Show::Queue \
                          -rtrObj $rObj \
                          -name "${QUEUE_PREFIX}*"\
                          -msgVpn $msgVpn ]

        set domObj [[keylget retK_Q_List "domObj"] documentElement]
        set qNodes [$domObj selectNodes "//queue/queues/queue"]

        foreach qNode $qNodes {

            set qName [::SolDom::GetElementTextFromNode $qNode "name"]
            if {$qName != ""} {
                   ::L1::QueueShutdown \
                      -rtrObj        $rObj \
                      -action        [::Const::CFG_ADD] \
                      -msgVpn        $msgVpn \
                      -queueName     $qName 
                    ::L1::Queue \
                       -rtrObj        $rObj \
                       -action        [::Const::CFG_REMOVE] \
                       -msgVpn        $msgVpn \
                       -name          $qName 
            }
        }

        set retK_DTE_List [::L1::Show::TopicEndpoint \
                          -rtrObj $rObj \
                          -name "${TOPIC_ENDPOINT_PREFIX}*"\
                          -msgVpn $msgVpn ]

        set domObj [[keylget retK_DTE_List "domObj"] documentElement]
        set dteNodes [$domObj selectNodes "//topic-endpoint/topic-endpoints/topic-endpoint"]

        foreach dteNode $dteNodes {

            set dteName [::SolDom::GetElementTextFromNode $dteNode "name"]
            if {$dteName != ""} {
                   ::L1::TopicEndpointShutdown \
                      -rtrObj        $rObj \
                      -action        [::Const::CFG_ADD] \
                      -msgVpn        $msgVpn \
                      -name     $dteName 
                    ::L1::DurableTopicEndpoint \
                       -rtrObj        $rObj \
                       -action        [::Const::CFG_REMOVE] \
                       -msgVpn        $msgVpn \
                       -name          $dteName 
            }
        }
    }
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the client-usernames and client profiles"
foreach rtrObj $rtrConfigObjList {
    foreach msgVpn $msgVpnList {
        ::L1::ClientUsernameShutdown \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_ADD] \
                      -clientUsername $PUB_SUB_USER \
                      -msgVpn         $msgVpn \
                      -mgmtPrtcl      $mgmtPrtcl
        ::L1::ClientUsername \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_REMOVE] \
                      -clientUsername $PUB_SUB_USER \
                      -msgVpn         $msgVpn \
                      -mgmtPrtcl      $mgmtPrtcl
        ::L1::ClientProfile \
                      -rtrObj         $rtrObj \
                      -action         [::Const::CFG_REMOVE] \
                      -profName       $PUB_SUB_PROFILE \
                      -msgVpn         $msgVpn \
                      -mgmtPrtcl      $mgmtPrtcl
    }
    ::L2::Verify::MgmtCommand \
               -cmd "::L1::ClientUsernameShutdown" \
               -params [ list \
                   -rtrObj             $rtrObj \
                   -msgVpn             "default" \
                   -clientUsername     "default" \
                   -action             [::Const::CFG_ADD]]
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Delete the HA clusters"
foreach haClusterObj $haClusterObjList {
    ::L3::ConfigAd \
        -haClusterObj       $haClusterObj \
        -isAA               [::Const::FALSE] \
        -action             [::Const::CFG_REMOVE]
}
::L1::Test::ActionEnd
##############################################################################################################################
incr actionNum
::L1::Test::ActionStart "$actionNum - Test Cleanup: Remove AD on standalone routers"
foreach rtrObj $standaloneObjList {
    ::L3::ConfigAd -rtrObjList $rtrObj \
        -action             [::Const::CFG_REMOVE]
}
::L1::Test::ActionEnd
############################################################################################
set expectedErrList [list]
lappend expectedErrList "'ZipEngine::handleLockupComplete"
lappend expectedErrList "ZipEngine::handleLockup"

if {[::L1::Rtr::IsCapable [::RtrProp::CAP_DMR_REPLICATION]] == [::Const::TRUE] } {
    lappend expectedErrList "Invalid bind: spoolerId=.* lastSpooledMsgId=.* lastPubMsgId=.* lastRxMsgId=.*"
}
# Once SOL-24482 is fixed, remove the if below
if {[::L1::Rtr::IsCapable [::RtrProp::CAP_DMR_REPLICATION]] == [::Const::TRUE] } {
    lappend expectedErrList "Failed changing bridge for client .*, messge VPN .* to bidirectional: not found"
    ::L1::Test::Result [::Const::LOG_RESULTS_EXPECTED_FAIL] "SOL-24482"
}

::L2::Test::End \
    -skipHardwareCheck [::Const::TRUE] \
    -expectedLogErrorList $expectedErrList \
    -expectedSdkErrorList "*Max Num Subscriptions Exceeded*" \
    -checkRedunEvents         [::Const::FALSE] \
    -checkCommandLogs         [::Const::FALSE]
###############
