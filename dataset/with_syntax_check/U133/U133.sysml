package ValvulotomeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BladeDeploymentState;
    attribute def IncisionDepth :> LengthValue;
    attribute def RotationalSpeed :> AngularVelocityValue;
    attribute def CuttingPrecision :> LengthValue;
    attribute def TissueResistance :> ForceValue;
    
    item def VenousValveLeaflet {
        attribute thickness : LengthValue;
        attribute fibrosisLevel : Real;
        attribute incised : Boolean;
    }
    
    item def BloodVessel {
        attribute innerDiameter : LengthValue;
        attribute wallThickness : LengthValue;
        attribute bloodPressure : PressureValue;
    }
    
    port def MechanicalControlPort {
        in deploymentCommand : BladeDeploymentState;
        in rotationCommand : RotationalSpeed;
        out positionFeedback : LengthValue;
        out forceFeedback : ForceValue;
    }
    
    port def SurgicalInterfacePort {
        out appliedForce : ForceValue;
        in tissueResponse : TissueResistance;
    }
    
    port def FluidPort {
        flow bloodFlow : VolumeFlowRateValue;
        flow pressure : PressureValue;
    }
    
    part def CuttingBlade {
        attribute bladeSharpness : Real;
        attribute edgeAngle : Real;
        attribute deployed : Boolean := false;
        port surgicalInterface : SurgicalInterfacePort;
    }
    
    part def RotationalMechanism {
        attribute currentSpeed : RotationalSpeed;
        attribute maxTorque : TorqueValue;
        attribute rotationAngle : Real;
    }
    
    part def CatheterShaft {
        attribute length : LengthValue;
        attribute flexibility : Real;
        attribute outerDiameter : LengthValue;
        port proximalControl : MechanicalControlPort;
        port distalTip : SurgicalInterfacePort;
    }
    
    part def HandleAssembly {
        attribute gripDiameter : LengthValue;
        attribute deploymentLeverPosition : Real;
        port operatorControl : MechanicalControlPort;
    }
    
    part def Valvulotome {
        part blade : CuttingBlade;
        part rotationMech : RotationalMechanism;
        part catheter : CatheterShaft;
        part handle : HandleAssembly;
        
        connection handleToCatheter connect handle.operatorControl to catheter.proximalControl;
        connection catheterToBlade connect catheter.distalTip to blade.surgicalInterface;
    }
    
    action def NavigateToValve {
        in targetVessel : BloodVessel;
        in insertionDepth : IncisionDepth;
        out positionReached : Boolean;
        out currentDepth : LengthValue;
    }
    
    action def DeployBlade {
        in deploymentCommand : BladeDeploymentState;
        inout bladeState : Boolean;
        out deploymentComplete : Boolean;
    }
    
    action def RotateCuttingBlade {
        in targetSpeed : RotationalSpeed;
        in targetAngle : Real;
        out currentAngle : Real;
        out rotationComplete : Boolean;
    }
    
    action def InciseValveLeaflet {
        in appliedForce : ForceValue;
        in bladeSharpness : Real;
        in leafletThickness : LengthValue;
        out incisionDepth : IncisionDepth;
        out incisionComplete : Boolean;
    }
    
    action def VerifyIncision {
        in preFlowRate : VolumeFlowRateValue;
        in postFlowRate : VolumeFlowRateValue;
        out flowRestored : Boolean;
    }
    
    action def RetractBlade {
        inout bladeState : Boolean;
        out retractionComplete : Boolean;
    }
    
    action def WithdrawCatheter {
        in currentDepth : LengthValue;
        out withdrawalComplete : Boolean;
    }
    
    action def PerformValvulotomy {
        in targetVessel : BloodVessel;
        in targetValve : VenousValveLeaflet;
        in targetDepth : IncisionDepth;
        out procedureSuccess : Boolean;
        out finalFlowRate : VolumeFlowRateValue;
        
        private attribute positioned : Boolean := false;
        private attribute bladeDeployed : Boolean := false;
        private attribute incisionDone : Boolean := false;
        private attribute baselineFlow : VolumeFlowRateValue;
        private attribute postProcedureFlow : VolumeFlowRateValue;
        
        first start;
        then merge prepareInsertion;
        
        then action navigate : NavigateToValve {
            in targetVessel = PerformValvulotomy::targetVessel;
            in insertionDepth = targetDepth;
            out positionReached;
            out currentDepth;
        }
        
        then decide;
            if navigate.positionReached then proceedToDeployment;
            if not navigate.positionReached then adjustPosition;
        
        action adjustPosition : NavigateToValve {
            in targetVessel = PerformValvulotomy::targetVessel;
            in insertionDepth = targetDepth;
            out positionReached;
            out currentDepth;
        }
        then prepareInsertion;
        
        action proceedToDeployment {
            action deployAction : DeployBlade {
                in deploymentCommand : BladeDeploymentState;
                inout bladeState = bladeDeployed;
                out deploymentComplete;
            }
            then assign bladeDeployed := deployAction.deploymentComplete;
            then action rotate : RotateCuttingBlade {
                in targetSpeed : RotationalSpeed;
                in targetAngle : Real;
                out currentAngle;
                out rotationComplete;
            }
            then action incise : InciseValveLeaflet {
                in appliedForce : ForceValue;
                in bladeSharpness : Real;
                in leafletThickness = targetValve.thickness;
                out incisionDepth;
                out incisionComplete;
            }
            then assign incisionDone := incise.incisionComplete;
        }
        
        then decide;
            if incisionDone then verifyAndRetract;
            if not incisionDone then repeatIncision;
        
        action repeatIncision : InciseValveLeaflet {
            in appliedForce : ForceValue;
            in bladeSharpness : Real;
            in leafletThickness = targetValve.thickness;
            out incisionDepth;
            out incisionComplete;
        }
        then assign incisionDone := repeatIncision.incisionComplete;
        then verifyAndRetract;
        
        action verifyAndRetract {
            action verify : VerifyIncision {
                in preFlowRate = baselineFlow;
                in postFlowRate = postProcedureFlow;
                out flowRestored;
            }
            then action retract : RetractBlade {
                inout bladeState = bladeDeployed;
                out retractionComplete;
            }
            then assign bladeDeployed := false;
            then action withdraw : WithdrawCatheter {
                in currentDepth = navigate.currentDepth;
                out withdrawalComplete;
            }
            then assign procedureSuccess := verify.flowRestored;
            then assign finalFlowRate := postProcedureFlow;
        }
        
        then done;
    }
    
    state def ValvulotomeOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign systemReady : Boolean := true;
        }
        
        transition idle_to_navigating
            first idle
            accept InsertCommand
            then navigating;
        
        state navigating {
            do action navigateAction : NavigateToValve;
        }
        
        transition navigating_to_positioned
            first navigating
            if navigateAction.positionReached
            then positioned;
        
        transition navigating_to_repositioning
            first navigating
            if not navigateAction.positionReached
            then repositioning;
        
        state repositioning {
            do action adjustAction : NavigateToValve;
        }
        
        transition repositioning_to_positioned
            first repositioning
            if adjustAction.positionReached
            then positioned;
        
        state positioned;
        
        transition positioned_to_bladeDeployed
            first positioned
            accept DeployCommand
            then bladeDeployed;
        
        state bladeDeployed {
            entry assign bladeActive : Boolean := true;
        }
        
        transition bladeDeployed_to_cutting
            first bladeDeployed
            accept RotateCommand
            then cutting;
        
        state cutting {
            do action cuttingAction : InciseValveLeaflet;
        }
        
        transition cutting_to_verifying
            first cutting
            if cuttingAction.incisionComplete
            then verifying;
        
        transition cutting_to_adjustingCut
            first cutting
            if not cuttingAction.incisionComplete
            then adjustingCut;
        
        state adjustingCut {
            do action recutAction : InciseValveLeaflet;
        }
        
        transition adjustingCut_to_verifying
            first adjustingCut
            if recutAction.incisionComplete
            then verifying;
        
        state verifying {
            do action verifyAction : VerifyIncision;
        }
        
        transition verifying_to_retracting
            first verifying
            then retracting;
        
        state retracting {
            do action retractAction : RetractBlade;
        }
        
        transition retracting_to_withdrawing
            first retracting
            if retractAction.retractionComplete
            then withdrawing;
        
        state withdrawing {
            do action withdrawAction : WithdrawCatheter;
        }
        
        transition withdrawing_to_idle
            first withdrawing
            if withdrawAction.withdrawalComplete
            then idle;
    }
    
    part valvulotomeSystem : Valvulotome {
        perform action valvulotomyProcedure : PerformValvulotomy[*] ordered;
        exhibit state operationalStates : ValvulotomeOperationalStates;
    }
    
    requirement def TherapeuticEffectiveness {
        doc /* The valvulotome system shall effectively restore venous blood flow 
               by precisely incising incompetent valve leaflets. */
        
        require constraint flowRestorationRequirement {
            doc /* Post-procedure blood flow shall increase by at least 50% compared 
                   to pre-procedure baseline in treated vessel segment. */
        }
        
        require constraint incisionPrecisionRequirement {
            doc /* Incision depth shall be controllable within 0.5mm tolerance to 
                   prevent vessel wall damage. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The valvulotome system shall minimize risk of vessel perforation, 
               thrombosis, and unintended tissue damage. */
        
        require constraint forceControlRequirement {
            doc /* Applied cutting force shall not exceed vessel wall tolerance 
                   threshold to prevent perforation. */
        }
        
        require constraint bladeRetentionRequirement {
            doc /* Cutting blade shall remain securely attached throughout procedure 
                   to prevent embolization. */
        }
    }
    
    requirement def UsabilityRequirement {
        doc /* The valvulotome system shall provide intuitive control and tactile 
               feedback for precise surgical manipulation. */
        
        require constraint ergonomicRequirement {
            doc /* Handle assembly shall accommodate standard surgical grip positions 
                   and minimize operator fatigue. */
        }
    }
    
    requirement <'VAL-SYS-001'> primaryFunction : TherapeuticEffectiveness {
        doc /* The valvulotome system shall perform minimally invasive endovascular 
               incision of incompetent venous valve leaflets to restore unidirectional 
               blood flow in patients with chronic venous insufficiency. The system 
               accomplishes this through controlled catheter navigation to the target 
               valve, precise deployment and rotation of a cutting blade, systematic 
               incision of valve tissue, and safe withdrawal while preserving vessel 
               integrity and preventing complications. */
        
        subject valvulotomeSystem;
        
        assume constraint patientCondition {
            doc /* Patient has confirmed chronic venous insufficiency with incompetent 
                   valves suitable for endovascular treatment. */
        }
        
        assume constraint vesselAccess {
            doc /* Target venous valve is accessible via percutaneous catheter approach 
                   with adequate vessel diameter. */
        }
        
        require primaryFunction.flowRestorationRequirement;
        require primaryFunction.incisionPrecisionRequirement;
        require safetyConstraints : SafetyRequirement;
        require usabilityConstraints : UsabilityRequirement;
    }
    
    satisfy primaryFunction by valvulotomeSystem.valvulotomyProcedure;
}
