package HighPressureMudPumpingSystem {
    import ScalarFunctions::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQSpeed::*;
    import ISQTorque::*;
    import ISQDensity::*;
    import ISQDynamicViscosity::*;
    import ISQFlowRate::*;

    // ===== Item and Value Types =====

    item def DrillingMud {
        attribute density :> massDensity;
        attribute viscosity :> dynamicViscosity;
        attribute temperature :> ThermodynamicTemperatureValue;
    }

    attribute def PressureThreshold :> PressureValue;
    attribute def FlowRateSetpoint :> VolumeFlowRateValue;
    attribute def SpeedCommand :> AngularSpeedValue;

    port def MudFlowPort {
        attribute pressure :> PressureValue;
        attribute flowRate :> VolumeFlowRateValue;
        out item mud : DrillingMud;
    }

    port def MudSuctionPort {
        attribute pressure :> PressureValue;
        attribute flowRate :> VolumeFlowRateValue;
        in item mud : DrillingMud;
    }

    port def MechanicalPowerPort {
        attribute rotationalSpeed :> AngularSpeedValue;
        attribute torque :> TorqueValue;
    }

    port def ControlSignalPort {
        attribute speedCommand : SpeedCommand;
        attribute flowFeedback : VolumeFlowRateValue;
        attribute pressureFeedback : PressureValue;
        attribute emergencyStop : Boolean;
    }

    // ===== Requirements =====

    requirement def MudPumpingRequirement {
        subject pumpSystem : HighPressureMudPumpingSystem;
        objective {
            doc /* The system shall circulate drilling mud from the mud pit to the wellbore at the required flow rate and pressure. */
        }
        require pumpSystem.dischargePressure <= 500 [bar];
        require pumpSystem.targetFlowRate >= 1000 [gal/min];
    }

    requirement def SafetyRequirement {
        subject pumpSystem : HighPressureMudPumpingSystem;
        objective {
            doc /* The system shall transition to a safe state when discharge pressure exceeds the high-pressure limit or when emergency stop is activated. */
        }
        require pumpSystem.highPressureLimit <= 450 [bar];
        require pumpSystem.emergencyStopFunction == true;
    }

    requirement def FlowControlRequirement {
        subject pumpSystem : HighPressureMudPumpingSystem;
        objective {
            doc /* The system shall maintain the target flow rate within +/- 5% by adjusting the prime driver speed. */
        }
        require abs(pumpSystem.actualFlowRate - pumpSystem.targetFlowRate) <= 0.05 * pumpSystem.targetFlowRate;
    }

    // ===== Component Part Definitions =====

    part def MudPit {
        attribute capacity :> VolumeValue = 50 [m^3];
        attribute currentVolume :> VolumeValue;
        port suctionOutlet : MudFlowPort;
        
        action def SupplyMud :> Action {
            out suppliedMud : DrillingMud;
        }
        perform supplyMud : SupplyMud;
    }

    part def SuctionLine {
        attribute diameter :> LengthValue = 0.3 [m];
        attribute length :> LengthValue = 5 [m];
        port inlet : MudSuctionPort;
        port outlet : MudFlowPort;
        
        flow mudFlow : DrillingMud from inlet.mud to outlet.mud;
    }

    part def PrimeDriver {
        attribute maxPower :> PowerValue = 1200 [kW];
        attribute currentSpeed :> AngularSpeedValue;
        attribute targetSpeed :> AngularSpeedValue;
        port mechanicalOutput : MechanicalPowerPort;
        port controlInput : ControlSignalPort;
        
        action def GeneratePower :> Action {
            in speedCmd : SpeedCommand;
            out torque : TorqueValue;
            out speed : AngularSpeedValue;
        }
        perform generatePower : GeneratePower;
    }

    part def PistonAssembly {
        attribute boreDiameter :> LengthValue = 0.15 [m];
        attribute strokeLength :> LengthValue = 0.3 [m];
        attribute strokeRate :> AngularSpeedValue;
        port mudIntake : MudSuctionPort;
        port mudDischarge : MudFlowPort;
        
        action def Reciprocate :> Action {
            in mudIn : DrillingMud;
            out mudOut : DrillingMud;
            attribute chamberPressure :> PressureValue;
        }
        perform reciprocate : Reciprocate;
    }

    part def PowerEnd {
        attribute gearRatio : Real = 4.5;
        port driverInput : MechanicalPowerPort;
        port fluidEndOutput : MechanicalPowerPort;
        
        action def ConvertPower :> Action {
            in inputTorque : TorqueValue;
            in inputSpeed : AngularSpeedValue;
            out outputTorque : TorqueValue;
            out outputSpeed : AngularSpeedValue;
        }
        perform convertPower : ConvertPower;
    }

    part def FluidEnd {
        port suctionInlet : MudSuctionPort;
        port dischargeOutlet : MudFlowPort;
        port mechanicalInput : MechanicalPowerPort;
        part pistonA : PistonAssembly;
        part pistonB : PistonAssembly;
        part pistonC : PistonAssembly;
        
        connection mechanicalDistrib : MechanicalPowerPort from mechanicalInput to pistonA.mudIntake;
        
        action def PressurizeMud :> Action {
            in mudIn : DrillingMud;
            out mudOut : DrillingMud;
            attribute dischargePressure :> PressureValue;
        }
        perform pressurizeMud : PressurizeMud;
    }

    part def MudPump {
        attribute ratedPressure :> PressureValue = 350 [bar];
        attribute ratedFlowRate :> VolumeFlowRateValue = 1200 [gal/min];
        port suctionPort : MudSuctionPort;
        port dischargePort : MudFlowPort;
        port driverPort : MechanicalPowerPort;
        part powerEnd : PowerEnd;
        part fluidEnd : FluidEnd;
        
        connection driverToPowerEnd : MechanicalPowerPort from driverPort to powerEnd.driverInput;
        connection powerEndToFluidEnd : MechanicalPowerPort from powerEnd.fluidEndOutput to fluidEnd.mechanicalInput;
        connection suctionToFluidEnd : MudSuctionPort from suctionPort to fluidEnd.suctionInlet;
        connection fluidEndToDischarge : MudFlowPort from fluidEnd.dischargeOutlet to dischargePort;
    }

    part def DischargeLine {
        attribute diameter :> LengthValue = 0.1 [m];
        attribute length :> LengthValue = 20 [m];
        attribute maxPressure :> PressureValue = 500 [bar];
        port inlet : MudSuctionPort;
        port outlet : MudFlowPort;
        
        flow mudFlow : DrillingMud from inlet.mud to outlet.mud;
    }

    part def Wellbore {
        attribute depth :> LengthValue = 3000 [m];
        attribute bottomPressure :> PressureValue;
        port mudInlet : MudSuctionPort;
        
        action def ReceiveMud :> Action {
            in mud : DrillingMud;
            attribute receivedFlowRate :> VolumeFlowRateValue;
        }
        perform receiveMud : ReceiveMud;
    }

    part def ControlSystem {
        attribute targetFlowRate :> VolumeFlowRateValue = 1200 [gal/min];
        attribute highPressureLimit :> PressureValue = 450 [bar];
        attribute emergencyStopActive : Boolean = false;
        port sensorInput : ControlSignalPort;
        port driverOutput : ControlSignalPort;
        
        action def MonitorAndControl :> Action {
            in pressureFeedback : PressureValue;
            in flowFeedback : VolumeFlowRateValue;
            out speedCommand : SpeedCommand;
            attribute error :> VolumeFlowRateValue;
            attribute kp : Real = 0.5;
            attribute ki : Real = 0.1;
        }
        perform monitorAndControl : MonitorAndControl;
        
        state def ControlState {
            entry; then Monitoring;
            state Monitoring;
            transition Monitoring_to_EmergencyStop when sensorInput.emergencyStop == true;
            transition Monitoring_to_HighPressure when sensorInput.pressureFeedback > highPressureLimit;
            state HighPressure;
            transition HighPressure_to_Monitoring when sensorInput.pressureFeedback <= highPressureLimit;
            state EmergencyStop;
            transition EmergencyStop_to_Monitoring when sensorInput.emergencyStop == false;
        }
        state controlStateMachine : ControlState;
    }

    // ===== Top-Level System =====

    part def HighPressureMudPumpingSystem {
        attribute dischargePressure :> PressureValue;
        attribute targetFlowRate :> VolumeFlowRateValue = 1200 [gal/min];
        attribute actualFlowRate :> VolumeFlowRateValue;
        attribute highPressureLimit :> PressureValue = 450 [bar];
        attribute emergencyStopFunction : Boolean = true;
        
        part mudPit : MudPit;
        part suctionLine : SuctionLine;
        part primeDriver : PrimeDriver;
        part mudPump : MudPump;
        part dischargeLine : DischargeLine;
        part wellbore : Wellbore;
        part controlSystem : ControlSystem;
        
        connection pitToSuction : MudFlowPort from mudPit.suctionOutlet to suctionLine.inlet;
        connection suctionToPump : MudSuctionPort from suctionLine.outlet to mudPump.suctionPort;
        connection driverToPump : MechanicalPowerPort from primeDriver.mechanicalOutput to mudPump.driverPort;
        connection pumpToDischarge : MudFlowPort from mudPump.dischargePort to dischargeLine.inlet;
        connection dischargeToWellbore : MudFlowPort from dischargeLine.outlet to wellbore.mudInlet;
        connection controlToDriver : ControlSignalPort from controlSystem.driverOutput to primeDriver.controlInput;
        connection pumpFeedbackToControl : ControlSignalPort from mudPump.dischargePort to controlSystem.sensorInput;
        
        // System-level state machine
        state def SystemLifecycle {
            entry; then Idle;
            state Idle {
                entry action { /* Initialize system, verify readiness */ }
            }
            transition Idle_to_Starting when controlSystem.driverOutput.speedCommand > 0 [rpm];
            state Starting {
                entry action { /* Ramp up prime driver, engage pump */ }
            }
            transition Starting_to_Running when primeDriver.currentSpeed >= primeDriver.targetSpeed * 0.95;
            state Running {
                entry action { /* Normal operation, mud circulation active */ }
            }
            transition Running_to_Stopping when controlSystem.driverOutput.speedCommand == 0 [rpm];
            transition Running_to_HighPressure when dischargePressure > highPressureLimit;
            state HighPressure {
                entry action { /* Alert operator, reduce speed */ }
            }
            transition HighPressure_to_Running when dischargePressure <= highPressureLimit * 0.9;
            transition HighPressure_to_Stopping when controlSystem.sensorInput.emergencyStop == true;
            state Stopping {
                entry action { /* Controlled shutdown of pump and driver */ }
            }
            transition Stopping_to_Idle when primeDriver.currentSpeed == 0 [rpm];
            state EmergencyStopped {
                entry action { /* Immediate halt, isolate discharge */ }
            }
            transition any_to_EmergencyStopped when controlSystem.sensorInput.emergencyStop == true;
            transition EmergencyStopped_to_Idle when controlSystem.sensorInput.emergencyStop == false;
        }
        state systemStateMachine : SystemLifecycle;
        
        // System-level action for circulation
        action def CirculateMud :> Action {
            in mudFromPit : DrillingMud;
            out mudToWellbore : DrillingMud;
            attribute circulatedVolume :> VolumeValue;
            attribute circulationTime :> TimeValue;
        }
        perform circulateMud : CirculateMud;
        
        satisfy mudPumpingRequirement : MudPumpingRequirement;
        satisfy safetyRequirement : SafetyRequirement;
        satisfy flowControlRequirement : FlowControlRequirement;
    }
}
