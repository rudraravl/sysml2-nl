package DrillingMudCirculationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def PressureValue :> Real { unit 'Pa'; }
    value def FlowRateValue :> Real { unit 'm3/s'; }
    value def DensityValue :> Real {> MassDensityValue; }
    value def ViscosityValue :> Real { unit 'Pa*s'; }
    value def pHValue :> Real;
    value def TemperatureValue :> Real {> ThermodynamicTemperatureValue; }
    value def VolumeValue :> Real {> VolumeValue; }
    value def PowerValue :> Real {> PowerValue; }
    value def RotationalSpeedValue :> Real { unit 'rad/s'; }
    value def LengthValue :> Real {> LengthValue; }
    value def AreaValue :> Real {> AreaValue; }
    value def MassFlowRateValue :> Real {> MassFlowRateValue; }

    // ---------- Items ----------
    item def Mud {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute pH : pHValue;
        attribute temperature : TemperatureValue;
    }

    item def Cuttings {
        attribute particleSize : LengthValue;
        attribute massFlow : MassFlowRateValue;
    }

    item def MudCuttingsMixture {
        attribute mud : Mud;
        attribute cuttings : Cuttings;
        attribute concentration : Real; // fraction
    }

    // ---------- Port Definitions ----------
    port def MudPort {
        out item mud : Mud;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def MudInPort {
        in item mud : Mud;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def MudOutPort {
        out item mud : Mud;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def MixtureInPort {
        in item mixture : MudCuttingsMixture;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def MixtureOutPort {
        out item mixture : MudCuttingsMixture;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def CleanedMudOutPort {
        out item mud : Mud;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def CuttingsOutPort {
        out item cuttings : Cuttings;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def SensorDataPort {
        out attribute density : DensityValue;
        out attribute viscosity : ViscosityValue;
        out attribute pH : pHValue;
        out attribute temperature : TemperatureValue;
        out attribute flowRate : FlowRateValue;
        out attribute pressure : PressureValue;
    }

    // ---------- Interfaces ----------
    interface def MudFlowInterface {
        end supplier : MudOutPort;
        end consumer : MudInPort;
    }

    interface def MixtureFlowInterface {
        end supplier : MixtureOutPort;
        end consumer : MixtureInPort;
    }

    interface def CleanedMudInterface {
        end supplier : CleanedMudOutPort;
        end consumer : MudInPort;
    }

    interface def SensorDataInterface {
        end supplier : SensorDataPort;
        end consumer : ControlPort;
    }

    // ---------- Components ----------
    part def MudPits {
        attribute capacity : VolumeValue = 100 [m3];
        attribute currentVolume : VolumeValue;
        port mudOut : MudOutPort;
        port mudIn : MudInPort;
        port control : ControlPort;

        attribute storedMud : Mud;

        state def MudPitsStates {
            entry; then Idle;
            state Idle;
            transition idle_to_active
                first Idle
                if control.command == "start"
                then Active;
            state Active {
                entry action { currentVolume = currentVolume; }
            }
            transition active_to_idle
                first Active
                if control.command == "stop"
                then Idle;
        }
    }

    part def MudPump {
        attribute ratedPower : PowerValue = 1500 [kW];
        attribute dischargePressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute pumpSpeed : RotationalSpeedValue;

        port mudIn : MudInPort;
        port mudOut : MudOutPort;
        port control : ControlPort;

        state def PumpStates {
            entry; then Off;
            state Off;
            transition off_to_starting
                first Off
                if control.command == "start"
                then Starting;
            state Starting {
                entry action { pumpSpeed = 0.0; }
                do action { pumpSpeed = pumpSpeed + 1.0; }
                transition starting_to_running
                    first Starting
                    if pumpSpeed >= 100.0
                    then Running;
            }
            state Running {
                entry action { dischargePressure = 30e6 [Pa]; flowRate = 0.05 [m3/s]; }
            }
            transition running_to_stopping
                first Running
                if control.command == "stop"
                then Stopping;
            state Stopping {
                do action { pumpSpeed = pumpSpeed - 1.0; }
                transition stopping_to_off
                    first Stopping
                    if pumpSpeed <= 0.0
                    then Off;
            }
        }
    }

    part def DrillString {
        attribute length : LengthValue = 1000 [m];
        attribute internalDiameter : LengthValue = 0.1 [m];
        port mudIn : MudInPort;
        port mudOut : MudOutPort;
    }

    part def DrillBit {
        attribute nozzleArea : AreaValue = 0.0005 [m2];
        attribute bitTemperature : TemperatureValue;
        port mudIn : MudInPort;
        port mixtureOut : MixtureOutPort;
        port control : ControlPort;

        action def cutRock {
            in mudIn : Mud;
            out mixtureOut : MudCuttingsMixture;
            attribute generatedCuttings : Cuttings;
            attribute coolingEffect : TemperatureValue;
        }
    }

    part def Annulus {
        attribute length : LengthValue = 1000 [m];
        attribute outerDiameter : LengthValue = 0.3 [m];
        attribute innerDiameter : LengthValue = 0.1 [m];
        port mixtureIn : MixtureInPort;
        port mixtureOut : MixtureOutPort;
    }

    part def ShakerScreen {
        attribute meshSize : LengthValue = 0.0002 [m];
        attribute vibrationFrequency : Real = 20.0;
        port mixtureIn : MixtureInPort;
        port cleanedMudOut : CleanedMudOutPort;
        port cuttingsOut : CuttingsOutPort;
        port control : ControlPort;

        action def separateCuttings {
            in mixture : MudCuttingsMixture;
            out cleanedMud : Mud;
            out cuttings : Cuttings;
        }
    }

    part def MudConditioner {
        attribute targetDensity : DensityValue = 1200 [kg/m3];
        attribute targetViscosity : ViscosityValue = 0.03 [Pa*s];
        attribute targetpH : pHValue = 9.5;

        port mudIn : MudInPort;
        port mudOut : MudOutPort;
        port control : ControlPort;

        action def conditionMud {
            in mudIn : Mud;
            out mudOut : Mud;
            attribute adjustedDensity : DensityValue;
            attribute adjustedViscosity : ViscosityValue;
            attribute adjustedpH : pHValue;
        }
    }

    part def MudSensors {
        port mudIn : MudInPort;
        port mudOut : MudOutPort;
        port sensorData : SensorDataPort;

        action def measure {
            in mud : Mud;
            out density : DensityValue;
            out viscosity : ViscosityValue;
            out pH : pHValue;
            out temperature : TemperatureValue;
        }
    }

    part def ControlSystem {
        port control : ControlPort;
        port sensorData : ControlPort;

        attribute targetFlowRate : FlowRateValue = 0.05 [m3/s];
        attribute targetPressure : PressureValue = 30e6 [Pa];

        state def ControlStates {
            entry; then Idle;
            state Idle;
            transition idle_to_startup
                first Idle
                if control.command == "startup"
                then Startup;
            state Startup {
                do action { control.command = "start"; }
                transition startup_to_normal
                    first Startup
                    if control.status == "running"
                    then NormalCirculation;
            }
            state NormalCirculation {
                do action { 
                    // continuously monitor and adjust
                }
                transition normal_to_shutdown
                    first NormalCirculation
                    if control.command == "shutdown"
                    then Shutdown;
            }
            state Shutdown {
                do action { control.command = "stop"; }
                transition shutdown_to_idle
                    first Shutdown
                    if control.status == "stopped"
                    then Idle;
            }
        }
    }

    // ---------- Top-level System ----------
    part def DrillingMudCirculationSystem {

        port systemControl : ControlPort;

        part mudPits : MudPits;
        part mudPump : MudPump;
        part drillString : DrillString;
        part drillBit : DrillBit;
        part annulus : Annulus;
        part shakerScreen : ShakerScreen;
        part mudConditioner : MudConditioner;
        part mudSensors : MudSensors;
        part controlSystem : ControlSystem;

        // Connections forming the closed loop
        interface mudPits_to_pump : MudFlowInterface connect
            mudPits.mudOut to mudPump.mudIn;

        interface pump_to_drillString : MudFlowInterface connect
            mudPump.mudOut to drillString.mudIn;

        interface drillString_to_bit : MudFlowInterface connect
            drillString.mudOut to drillBit.mudIn;

        interface bit_to_annulus : MixtureFlowInterface connect
            drillBit.mixtureOut to annulus.mixtureIn;

        interface annulus_to_shaker : MixtureFlowInterface connect
            annulus.mixtureOut to shakerScreen.mixtureIn;

        interface shaker_to_conditioner : CleanedMudInterface connect
            shakerScreen.cleanedMudOut to mudConditioner.mudIn;

        interface conditioner_to_sensors : MudFlowInterface connect
            mudConditioner.mudOut to mudSensors.mudIn;

        interface sensors_to_pits : MudFlowInterface connect
            mudSensors.mudOut to mudPits.mudIn;

        // Control connections
        flow controlSystem.control to mudPits.control;
        flow controlSystem.control to mudPump.control;
        flow controlSystem.control to drillBit.control;
        flow controlSystem.control to shakerScreen.control;
        flow controlSystem.control to mudConditioner.control;

        // Sensor data feedback
        flow mudSensors.sensorData to controlSystem.sensorData;

        // System-level state machine
        state def SystemStates {
            entry; then Idle;
            state Idle {
                entry action { systemControl.status = "idle"; }
            }
            transition idle_to_startup
                first Idle
                if systemControl.command == "startup"
                then Startup;
            state Startup {
                entry action { systemControl.status = "starting"; }
                do action { controlSystem.control.command = "startup"; }
                transition startup_to_normal
                    first Startup
                    if controlSystem.control.status == "running"
                    then NormalCirculation;
            }
            state NormalCirculation {
                entry action { systemControl.status = "circulating"; }
                do action {
                    // maintain wellbore stability
                    // remove cuttings efficiently
                    // prevent drill bit overheating
                }
                transition normal_to_shutdown
                    first NormalCirculation
                    if systemControl.command == "shutdown"
                    then Shutdown;
            }
            state Shutdown {
                entry action { systemControl.status = "shutting down"; }
                do action { controlSystem.control.command = "shutdown"; }
                transition shutdown_to_idle
                    first Shutdown
                    if controlSystem.control.status == "stopped"
                    then Idle;
            }
        }

        // Requirements
        requirement def CirculationRequirement {
            subject system : DrillingMudCirculationSystem;
            requirement {
                /* The system shall continuously circulate drilling mud in a closed loop. */
            }
        }

        requirement def MudPropertyRequirement {
            subject mud : Mud;
            attribute minDensity : DensityValue = 1000 [kg/m3];
            attribute maxDensity : DensityValue = 1500 [kg/m3];
            attribute minViscosity : ViscosityValue = 0.01 [Pa*s];
            attribute maxViscosity : ViscosityValue = 0.1 [Pa*s];
            attribute minpH : pHValue = 8.0;
            attribute maxpH : pHValue = 11.0;
            requirement {
                /* Mud density shall be between minDensity and maxDensity. */
            }
            requirement {
                /* Mud viscosity shall be between minViscosity and maxViscosity. */
            }
            requirement {
                /* Mud pH shall be between minpH and maxpH. */
            }
        }

        requirement def CuttingRemovalRequirement {
            subject shaker : ShakerScreen;
            requirement {
                /* The shaker screen shall separate solid cuttings from the liquid mud. */
            }
        }

        requirement def BitCoolingRequirement {
            subject bit : DrillBit;
            attribute maxBitTemperature : TemperatureValue = 150 [K] + 273.15 [K];
            requirement {
                /* The drill bit temperature shall not exceed maxBitTemperature during normal circulation. */
            }
        }

        requirement def PumpPressureRequirement {
            subject pump : MudPump;
            attribute minDischargePressure : PressureValue = 20e6 [Pa];
            requirement {
                /* The mud pump shall maintain discharge pressure above minDischargePressure during normal circulation. */
            }
        }

        requirement def SystemStateRequirement {
            subject system : DrillingMudCirculationSystem;
            requirement {
                /* The system shall operate in idle, startup, normal circulation, and shutdown states. */
            }
        }

        requirement circulationReq : CirculationRequirement {
            subject system = DrillingMudCirculationSystem::this;
        }

        requirement mudPropReq : MudPropertyRequirement {
            subject mud = mudSensors.mudIn.mud;
        }

        requirement cuttingRemovalReq : CuttingRemovalRequirement {
            subject shaker = shakerScreen;
        }

        requirement bitCoolingReq : BitCoolingRequirement {
            subject bit = drillBit;
        }

        requirement pumpPressureReq : PumpPressureRequirement {
            subject pump = mudPump;
        }

        requirement systemStateReq : SystemStateRequirement {
            subject system = DrillingMudCirculationSystem::this;
        }
    }
}
