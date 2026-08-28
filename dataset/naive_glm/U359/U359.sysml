package PortableOxygenConcentrator {
    import ISQ::*;
    import ScalarValues::*;

    // Item Definitions
    item def Air;
    item def Oxygen;
    item def WasteGas;

    // Value Definitions
    value def PressureValue :> Real { unit 'kPa'; }
    value def FlowRateValue :> Real { unit 'L/min'; }
    value def PurityValue :> Real { unit '%'; }
    value def BatteryLevelValue :> Real { unit '%'; }
    value def PowerValue :> Real { unit 'W'; }

    // Port Definitions
    port def AirOutPort { out air : Air; }
    port def AirInPort { in air : Air; }
    port def OxygenOutPort { out oxygen : Oxygen; }
    port def OxygenInPort { in oxygen : Oxygen; }
    port def WasteOutPort { out waste : WasteGas; }
    port def WasteInPort { in waste : WasteGas; }
    port def PowerOutPort { out power : PowerValue; }
    port def PowerInPort { in power : PowerValue; }
    port def ControlOutPort { out cmd : Real; }
    port def ControlInPort { in cmd : Real; }
    port def SensorOutPort { out reading : Real; }
    port def SensorInPort { in reading : Real; }
    port def UIOutPort { out setting : Real; }
    port def UIInPort { in setting : Real; }
    port def DisplayOutPort { out info : String; }
    port def DisplayInPort { in info : String; }

    // Connection Definitions
    connection def AirConnection {
        end source : AirOutPort;
        end target : AirInPort;
    }
    connection def OxygenConnection {
        end source : OxygenOutPort;
        end target : OxygenInPort;
    }
    connection def WasteConnection {
        end source : WasteOutPort;
        end target : WasteInPort;
    }
    connection def PowerConnection {
        end source : PowerOutPort;
        end target : PowerInPort;
    }
    connection def ControlConnection {
        end source : ControlOutPort;
        end target : ControlInPort;
    }
    connection def SensorConnection {
        end source : SensorOutPort;
        end target : SensorInPort;
    }
    connection def UIInputConnection {
        end source : UIOutPort;
        end target : UIInPort;
    }
    connection def UIDisplayConnection {
        end source : DisplayOutPort;
        end target : DisplayInPort;
    }

    // Part Definitions
    part def IntakeFilter {
        port ambientAir : AirInPort;
        port filteredAir : AirOutPort;
    }

    part def Compressor {
        port filteredAirIn : AirInPort;
        port pressurizedAirOut : AirOutPort;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
    }

    part def MolecularSieve {
        port pressurizedAirIn : AirInPort;
        port concentratedOxygenOut : OxygenOutPort;
        port wasteNitrogenOut : WasteOutPort;
    }

    part def FlowRegulator {
        port concentratedOxygenIn : OxygenInPort;
        port regulatedOxygenOut : OxygenOutPort;
        port controlIn : ControlInPort;
    }

    part def OxygenSensor {
        port oxygenIn : OxygenInPort;
        port dataOut : SensorOutPort;
    }

    part def PressureSensor {
        port airIn : AirInPort;
        port dataOut : SensorOutPort;
    }

    part def FlowSensor {
        port oxygenIn : OxygenInPort;
        port dataOut : SensorOutPort;
    }

    part def BatteryPack {
        port powerOut : PowerOutPort;
        port chargeIn : PowerInPort;
        port dataOut : SensorOutPort;
    }

    part def ACAdapter {
        port wallPowerIn : PowerInPort;
        port devicePowerOut : PowerOutPort;
        port batteryChargeOut : PowerOutPort;
    }

    part def UserInterface {
        port userInputOut : UIOutPort;
        port displayIn : DisplayInPort;
        port alarmIn : DisplayInPort;
    }

    part def ControlModule {
        port powerIn : PowerInPort;
        port uiInput : UIInPort;
        port uiDisplay : DisplayOutPort;
        port uiAlarm : DisplayOutPort;
        port batteryData : SensorInPort;
        port oxygenSensorData : SensorInPort;
        port pressureSensorData : SensorInPort;
        port flowSensorData : SensorInPort;
        port compressorControl : ControlOutPort;
        port regulatorControl : ControlOutPort;
        
        attribute currentMode : String;
        
        state machine ControlStateMachine {
            state Standby;
            state ContinuousFlow;
            state PulseDose;
            state Alarm;
            
            transition Standby_to_ContinuousFlow first Standby then ContinuousFlow;
            transition ContinuousFlow_to_Standby first ContinuousFlow then Standby;
            transition ContinuousFlow_to_PulseDose first ContinuousFlow then PulseDose;
            transition PulseDose_to_ContinuousFlow first PulseDose then ContinuousFlow;
            transition any_to_Alarm first (Standby | ContinuousFlow | PulseDose) then Alarm;
            transition Alarm_to_Standby first Alarm then Standby;
        }
    }

    part def PortableOxygenConcentrator {
        part intakeFilter : IntakeFilter;
        part compressor : Compressor;
        part molecularSieve : MolecularSieve;
        part flowRegulator : FlowRegulator;
        part oxygenSensor : OxygenSensor;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controlModule : ControlModule;
        part batteryPack : BatteryPack;
        part acAdapter : ACAdapter;
        part userInterface : UserInterface;
        
        port patientOxygen : OxygenOutPort;
        port wasteVent : WasteOutPort;
        port wallPower : PowerInPort;
        
        connection : AirConnection connect intakeFilter.filteredAir to compressor.filteredAirIn;
        connection : AirConnection connect compressor.pressurizedAirOut to molecularSieve.pressurizedAirIn;
        connection : OxygenConnection connect molecularSieve.concentratedOxygenOut to flowRegulator.concentratedOxygenIn;
        connection : WasteConnection connect molecularSieve.wasteNitrogenOut to wasteVent;
        
        connection : OxygenConnection connect flowRegulator.regulatedOxygenOut to oxygenSensor.oxygenIn;
        connection : OxygenConnection connect flowRegulator.regulatedOxygenOut to flowSensor.oxygenIn;
        connection : AirConnection connect compressor.pressurizedAirOut to pressureSensor.airIn;
        
        connection : SensorConnection connect oxygenSensor.dataOut to controlModule.oxygenSensorData;
        connection : SensorConnection connect pressureSensor.dataOut to controlModule.pressureSensorData;
        connection : SensorConnection connect flowSensor.dataOut to controlModule.flowSensorData;
        connection : SensorConnection connect batteryPack.dataOut to controlModule.batteryData;
        
        connection : ControlConnection connect controlModule.compressorControl to compressor.controlIn;
        connection : ControlConnection connect controlModule.regulatorControl to flowRegulator.controlIn;
        
        connection : UIInputConnection connect userInterface.userInputOut to controlModule.uiInput;
        connection : UIDisplayConnection connect controlModule.uiDisplay to userInterface.displayIn;
        connection : UIDisplayConnection connect controlModule.uiAlarm to userInterface.alarmIn;
        
        connection : PowerConnection connect acAdapter.devicePowerOut to controlModule.powerIn;
        connection : PowerConnection connect acAdapter.batteryChargeOut to batteryPack.chargeIn;
        connection : PowerConnection connect batteryPack.powerOut to controlModule.powerIn;
        
        binding connect flowRegulator.regulatedOxygenOut to patientOxygen;
        binding connect molecularSieve.wasteNitrogenOut to wasteVent;
        binding connect wallPower to acAdapter.wallPowerIn;
    }

    // Requirements
    requirement def OxygenConcentratorRequirements {
        subject poc : PortableOxygenConcentrator;
        
        requirement def PortabilityRequirement {
            doc "The device shall be compact, battery-powered, and intended for ambulatory use."
        }
        requirement def OxygenPurityRequirement {
            doc "The device shall provide supplemental, high-purity oxygen to patients."
            attribute minPurity : PurityValue = 90;
        }
        requirement def NitrogenVentingRequirement {
            doc "The separated nitrogen shall be safely vented out as waste."
        }
        requirement def FlowControlRequirement {
            doc "A flow regulator shall allow the user to set a specific delivery rate."
        }
        requirement def SafetyMonitoringRequirement {
            doc "The system shall be equipped with sensors to monitor oxygen purity, pressure, and flow."
        }
        requirement def AlarmRequirement {
            doc "If the system detects low oxygen purity, incorrect pressure, or a low battery, it shall trigger an alarm."
        }
        requirement def PowerManagementRequirement {
            doc "The device shall be powered by a rechargeable battery pack and include an AC power adapter for direct power and recharging."
        }
    }
}
