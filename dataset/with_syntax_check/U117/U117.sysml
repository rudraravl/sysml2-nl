package 'Sling System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LaunchCommand;
	attribute def LoadCommand;
	attribute def ReleaseCommand;
	attribute def FaultCondition;
	attribute def ResetCommand;
	
	attribute def SafetyStatus {
		attribute locked : Boolean;
	}
	
	value def ElasticConstant {
		attribute springConstant : Real;
		attribute unit : String;
	}
	
	item def Projectile {
		attribute mass : MassValue;
		attribute diameter : LengthValue;
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
	}
	
	item def ElasticCord {
		attribute restLength : LengthValue;
		attribute currentLength : LengthValue;
		attribute elasticConstant : ElasticConstant;
		attribute maxStretch : LengthValue;
		attribute storedEnergy : EnergyValue;
	}
	
	port def ProjectileLoadPort {
		in item projectileIn : Projectile;
		out item projectileOut : Projectile;
	}
	
	port def EnergyTransferPort {
		in energy : EnergyValue;
		out velocity : SpeedValue;
	}
	
	port def ControlPort {
		in command : LaunchCommand;
		out status : SafetyStatus;
	}
	
	part def Frame {
		attribute frameMass : MassValue;
		attribute height : LengthValue;
		attribute baseWidth : LengthValue;
		attribute material : String;
	}
	
	part def Pouch {
		attribute pouchMass : MassValue;
		attribute capacity : MassValue;
		port loadPort : ProjectileLoadPort;
	}
	
	part def ElasticSystem {
		part leftCord : ElasticCord {
			attribute restLength = 0.25[m];
			attribute currentLength = 0.25[m];
			attribute elasticConstant : ElasticConstant {
				attribute springConstant = 500.0;
				attribute unit = "N/m";
			}
			attribute maxStretch = 0.75[m];
			attribute storedEnergy = 0.0[J];
		}
		part rightCord : ElasticCord {
			attribute restLength = 0.25[m];
			attribute currentLength = 0.25[m];
			attribute elasticConstant : ElasticConstant {
				attribute springConstant = 500.0;
				attribute unit = "N/m";
			}
			attribute maxStretch = 0.75[m];
			attribute storedEnergy = 0.0[J];
		}
		port energyPort : EnergyTransferPort;
	}
	
	part def TriggerMechanism {
		attribute engaged : Boolean;
		port controlPort : ControlPort;
	}
	
	action def LoadProjectileAction {
		in projectile : Projectile;
		in pouchCapacity : MassValue;
		out loaded : Boolean;
		out loadedProjectile : Projectile;
	}
	
	action def DrawElasticAction {
		in cords : ElasticCord[2];
		in drawDistance : LengthValue;
		out stretchedCords : ElasticCord[2];
		out totalEnergy : EnergyValue;
	}
	
	action def AimAction {
		in targetRange : LengthValue;
		in projectileMass : MassValue;
		out launchAngle : AngleValue;
	}
	
	action def ReleaseAction {
		in storedEnergy : EnergyValue;
		in projectileMass : MassValue;
		in angle : AngleValue;
		out exitVelocity : SpeedValue;
		out launchedProjectile : Projectile;
	}
	
	action def CalculateTrajectoryAction {
		in velocity : SpeedValue;
		in angle : AngleValue;
		in mass : MassValue;
		out range : LengthValue;
		out flightTime : TimeValue;
	}
	
	part def SlingLauncher {
		attribute systemStatus : String;
		attribute safetyLock : SafetyStatus {
			attribute locked = true;
		}
		
		part structure : Frame {
			attribute frameMass = 0.8[kg];
			attribute height = 0.4[m];
			attribute baseWidth = 0.2[m];
			attribute material = "aluminum alloy";
		}
		
		part elastics : ElasticSystem;
		
		part projectileHolder : Pouch {
			attribute pouchMass = 0.05[kg];
			attribute capacity = 1.0[kg];
		}
		
		part trigger : TriggerMechanism {
			attribute engaged = false;
		}
		
		port projectileInterface : ProjectileLoadPort;
		port energyInterface : EnergyTransferPort;
		port controlInterface : ControlPort;
		
		connect projectileHolder.loadPort to projectileInterface;
		connect elastics.energyPort to energyInterface;
		connect trigger.controlPort to controlInterface;
	}
	
	action def LaunchSequence {
		in targetDistance : LengthValue;
		in projectileToLaunch : Projectile;
		out launchResult : Boolean;
		out achievedRange : LengthValue;
		
		first start;
		
		then action loadStep : LoadProjectileAction {
			in projectile = projectileToLaunch;
			in pouchCapacity = 1.0[kg];
			out loaded;
			out loadedProjectile;
		}
		
		then decide;
			if loadStep.loaded then proceedToDraw;
			if not loadStep.loaded then abortSequence;
		
		action proceedToDraw {
			action drawStep : DrawElasticAction {
				in cords[2];
				in drawDistance = 0.5[m];
				out stretchedCords[2];
				out totalEnergy;
			}
			
			then action aimStep : AimAction {
				in targetRange = targetDistance;
				in projectileMass = loadStep.loadedProjectile.mass;
				out launchAngle;
			}
			
			then accept releaseCmd : ReleaseCommand;
			
			then action releaseStep : ReleaseAction {
				in storedEnergy = drawStep.totalEnergy;
				in projectileMass = loadStep.loadedProjectile.mass;
				in angle = aimStep.launchAngle;
				out exitVelocity;
				out launchedProjectile;
			}
			
			then action trajectoryStep : CalculateTrajectoryAction {
				in velocity = releaseStep.exitVelocity;
				in angle = aimStep.launchAngle;
				in mass = loadStep.loadedProjectile.mass;
				out range;
				out flightTime;
			}
			
			then assign achievedRange := trajectoryStep.range;
			then assign launchResult := true;
		}
		then successComplete;
		
		action abortSequence {
			then assign launchResult := false;
			then assign achievedRange := 0.0[m];
		}
		then failureComplete;
		
		merge successComplete;
		merge failureComplete;
		then done;
	}
	
	state def SlingOperationalStates {
		in attribute systemStatus : String;
		in attribute safetyLock : SafetyStatus;
		
		entry; then ready;
		
		state ready {
			entry assign systemStatus := "ready";
		}
		
		transition ready_to_loading
			first ready
			accept LoadCommand
			then loading;
		
		state loading {
			entry assign systemStatus := "loading";
			do action loadAction : LoadProjectileAction;
		}
		
		transition loading_to_drawn
			first loading
			if loadAction.loaded
			then drawn;
		
		transition loading_to_ready
			first loading
			if not loadAction.loaded
			then ready;
		
		state drawn {
			entry assign systemStatus := "drawn";
			do action drawAction : DrawElasticAction;
		}
		
		transition drawn_to_aimed
			first drawn
			if drawAction.totalEnergy > 0.0[J]
			then aimed;
		
		state aimed {
			entry assign systemStatus := "aimed";
			do action aimAction : AimAction;
		}
		
		transition aimed_to_launching
			first aimed
			accept ReleaseCommand
			if not safetyLock.locked
			then launching;
		
		state launching {
			entry assign systemStatus := "launching";
			do action releaseAction : ReleaseAction;
		}
		
		transition launching_to_ready
			first launching
			then ready;
		
		state fault {
			entry assign systemStatus := "fault";
		}
		
		transition any_to_fault_from_ready
			first ready
			accept FaultCondition
			then fault;
		
		transition any_to_fault_from_loading
			first loading
			accept FaultCondition
			then fault;
		
		transition any_to_fault_from_drawn
			first drawn
			accept FaultCondition
			then fault;
		
		transition any_to_fault_from_aimed
			first aimed
			accept FaultCondition
			then fault;
		
		transition fault_to_ready
			first fault
			accept ResetCommand
			then ready;
	}
	
	part slingSystem : SlingLauncher {
		perform action launchOperation[*] ordered references LaunchSequence;
		
		exhibit state operationalBehavior : SlingOperationalStates {
			in systemStatus = slingSystem.systemStatus;
			in safetyLock = slingSystem.safetyLock;
		}
	}
	
	requirement def <'REQ-SL-001'> ProjectileLaunchCapability {
		doc /* The sling system shall launch projectiles with mass between 0.05 kg 
		       and 1.0 kg to distances between 10 meters and 100 meters. */
		
		subject launcher : SlingLauncher;
		
		require constraint massLimits {
			0.05[kg] <= launcher.projectileHolder.capacity and 
			launcher.projectileHolder.capacity <= 1.0[kg]
		}
		
		require constraint rangeLimits {
			doc /* System must achieve specified range with appropriate elastic energy */
		}
	}
	
	requirement def <'REQ-SL-002'> EnergyStorageCapability {
		doc /* The elastic system shall store sufficient energy to propel maximum 
		       projectile mass to maximum required distance without exceeding 
		       material limits. */
		
		subject elasticSys : ElasticSystem;
		
		require constraint energyCapacity {
			elasticSys.leftCord.storedEnergy + elasticSys.rightCord.storedEnergy >= 100.0[J]
		}
		
		require constraint stretchLimit {
			elasticSys.leftCord.currentLength <= elasticSys.leftCord.maxStretch and
			elasticSys.rightCord.currentLength <= elasticSys.rightCord.maxStretch
		}
	}
	
	requirement def <'REQ-SL-003'> SafetyRequirement {
		doc /* The sling system shall incorporate a safety mechanism that prevents 
		       accidental release and ensures controlled operation. */
		
		subject launcher : SlingLauncher;
		
		require constraint safetyInterlock {
			launcher.safetyLock.locked implies not launcher.trigger.engaged
		}
		
		require constraint controlledRelease {
			doc /* Release shall only occur when safety is disengaged and release command is received */
		}
	}
	
	requirement def <'REQ-SL-004'> StructuralIntegrity {
		doc /* The frame shall maintain structural integrity under maximum elastic 
		       tension without permanent deformation. */
		
		subject frame : Frame;
		
		require constraint massLimit {
			frame.frameMass <= 2.0[kg]
		}
		
		require constraint stability {
			doc /* Frame dimensions must provide stable base during operation */
		}
	}
	
	requirement <'SYS-SL-001'> slingSystemRequirements {
		doc /* The sling system shall provide a safe, reliable mechanism for launching 
		       projectiles using elastic energy storage and controlled release. */
		
		subject system : SlingLauncher;
		
		require <'REQ-SL-001'> ProjectileLaunchCapability;
		require <'REQ-SL-002'> EnergyStorageCapability;
		require <'REQ-SL-003'> SafetyRequirement;
		require <'REQ-SL-004'> StructuralIntegrity;
	}
	
	action def OperateSlingSystem {
		in targetRange : LengthValue;
		in projectile : Projectile;
		out success : Boolean;
		out range : LengthValue;
		
		first start;
		
		then action validateProjectile {
			in proj : Projectile;
			out valid : Boolean;
		}
		
		then decide;
			if validateProjectile.valid then executeLaunch;
			if not validateProjectile.valid then abort;
		
		action executeLaunch {
			action launch : LaunchSequence {
				in targetDistance = targetRange;
				in projectileToLaunch = projectile;
				out launchResult;
				out achievedRange;
			}
			then assign success := launch.launchResult;
			then assign range := launch.achievedRange;
		}
		then complete;
		
		action abort {
			then assign success := false;
			then assign range := 0.0[m];
		}
		then complete;
		
		merge complete;
		then done;
	}
}
