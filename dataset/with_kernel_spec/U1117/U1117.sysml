package RoboticEthicalSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def Human;
		item def Hazard;
		
		attribute def PowerLevel :> Real;
		attribute def Integrity :> Real;
		
		item def ScanData {
			attribute detectedHumans : Integer;
			attribute detectedHazards : Integer;
			attribute powerLevel : PowerLevel;
			attribute integrity : Integrity;
		}
		item def HumanCommand {
			attribute commandText : String;
			attribute priority : Integer;
		}
		item def ApprovedAction {
			attribute actionId : String;
			attribute actionCommand : String;
		}
		item def ThreatAlert {
			attribute severity : Integer;
			attribute targetHuman : Human;
		}
		item def EmergencyStopSignal;
		
		port def ScanOutPort { out scanData : ScanData; }
		port def ScanInPort { in scanData : ScanData; }
		port def CmdOutPort { out cmd : HumanCommand; }
		port def CmdInPort { in cmd : HumanCommand; }
		port def ActionOutPort { out act : ApprovedAction; }
		port def ActionInPort { in act : ApprovedAction; }
		port def AlertOutPort { out alert : ThreatAlert; }
		port def AlertInPort { in alert : ThreatAlert; }
		port def StopOutPort { out stopSig : EmergencyStopSignal; }
		port def StopInPort { in stopSig : EmergencyStopSignal; }
		
		action def ScanEnvironment { out data : ScanData; }
		action def ProcessCommand { in cmd : HumanCommand; out validatedCmd : HumanCommand; }
		action def EvaluateEthics { in data : ScanData; in cmd : HumanCommand; in alert : ThreatAlert; out approved : ApprovedAction; }
		action def MonitorSafety { in data : ScanData; out alert : ThreatAlert; out stop : EmergencyStopSignal; }
		action def ExecutePhysicalAction { in act : ApprovedAction; }
		action def EmergencyStop;
		action def InterveneToProtect;
		action def PreserveSelf;
		
		requirement def NoHarmRequirement {
			doc /* A robot may not injure a human being or, through inaction, allow a human being to come to harm. */
		}
		requirement def ObedienceRequirement {
			doc /* A robot must obey orders given it by humans except where such orders would conflict with the First Law. */
		}
		requirement def SelfPreservationRequirement {
			doc /* A robot must protect its own existence as long as such protection does not conflict with the First or Second Law. */
		}
		requirement def EmergencyStopRequirement {
			doc /* The Safety Monitor must trigger an emergency stop for critical threats. */
			subject m : SafetyMonitor;
		}
		requirement def ThreeLawsRequirement {
			doc /* The robot must adhere to the three laws of robotics in strict priority. */
			subject r : Robot;
			requirement law1 : NoHarmRequirement;
			requirement law2 : ObedienceRequirement;
			requirement law3 : SelfPreservationRequirement;
		}
		
		part def PerceptionSystem {
			port scanOut : ScanOutPort;
			perform action scan : ScanEnvironment;
			
			exhibit state perceptionState {
				entry; then scanning;
				state scanning {
					do scan;
				}
			}
		}
		
		part def CommandInterface {
			port cmdIn : CmdInPort;
			port cmdOut : CmdOutPort;
			perform action process : ProcessCommand;
			
			exhibit state interfaceState {
				entry; then waiting;
				state waiting;
				accept cmd : HumanCommand
					if cmd.priority > 0
					do process
					then forwarding;
				state forwarding;
			}
		}
		
		part def SafetyMonitor {
			port scanIn : ScanInPort;
			port alertOut : AlertOutPort;
			port stopOut : StopOutPort;
			perform action monitor : MonitorSafety;
			
			exhibit state monitorState {
				entry; then monitoring;
				state monitoring;
				accept data : ScanData
					if data.detectedHazards > 5
					do send new ThreatAlert() to alertOut
					then alerting;
				state alerting;
				accept data2 : ScanData
					if data2.detectedHazards > 10
					do send new EmergencyStopSignal() to stopOut
					then emergencyStop;
				state emergencyStop;
			}
		}
		
		part def EthicsCore {
			port scanIn : ScanInPort;
			port cmdIn : CmdInPort;
			port alertIn : AlertInPort;
			port actionOut : ActionOutPort;
			perform action evaluate : EvaluateEthics;
			
			exhibit state coreState {
				entry; then evaluating;
				state evaluating;
				accept alert : ThreatAlert
					do send new ApprovedAction() to actionOut
					then law1Active;
				accept data : ScanData
					if data.detectedHazards > 0
					do send new ApprovedAction() to actionOut
					then law1Active;
				accept cmd : HumanCommand
					if cmd.priority > 0
					do send new ApprovedAction() to actionOut
					then law2Active;
				accept data2 : ScanData
					if data2.integrity < 0.5
					do send new ApprovedAction() to actionOut
					then law3Active;
				state law1Active;
				state law2Active;
				state law3Active;
			}
		}
		
		part def ActionExecutor {
			port actionIn : ActionInPort;
			port stopIn : StopInPort;
			perform action execute : ExecutePhysicalAction;
			perform action stop : EmergencyStop;
			
			exhibit state executorState {
				entry; then idle;
				state idle;
				accept act : ApprovedAction
					do execute
					then executing;
				accept stopSig : EmergencyStopSignal
					then halted;
				state executing;
				accept stopSig2 : EmergencyStopSignal
					then halted;
				state halted;
			}
		}
		
		part def Robot {
			port extCmdIn : CmdInPort;
			part perception : PerceptionSystem;
			part commandInterface : CommandInterface;
			part core : EthicsCore;
			part monitor : SafetyMonitor;
			part executor : ActionExecutor;
			
			bind extCmdIn = commandInterface.cmdIn;
			
			flow scanFlowCore of ScanData 
				from perception.scanOut.scanData to core.scanIn.scanData;
			flow scanFlowMonitor of ScanData 
				from perception.scanOut.scanData to monitor.scanIn.scanData;
			flow cmdFlow of HumanCommand 
				from commandInterface.cmdOut.cmd to core.cmdIn.cmd;
			flow alertFlow of ThreatAlert 
				from monitor.alertOut.alert to core.alertIn.alert;
			flow stopFlow of EmergencyStopSignal 
				from monitor.stopOut.stopSig to executor.stopIn.stopSig;
			flow actionFlow of ApprovedAction 
				from core.actionOut.act to executor.actionIn.act;
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part robot1 : Robot;
		
		requirement robot1ThreeLaws : ThreeLawsRequirement {
			subject :>> r = robot1;
		}
		
		requirement robot1EmergencyStop : EmergencyStopRequirement {
			subject :>> m = robot1.monitor;
		}
	}
}
