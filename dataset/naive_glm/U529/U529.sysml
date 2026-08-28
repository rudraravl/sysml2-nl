package JetAerationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def VolumetricFlowRate :> Real { unit 'm3/s'; }
    value def PressureValue :> Real { unit 'Pa'; }
    value def DOConcentration :> Real { unit 'mg/L'; }
    value def PowerValue :> Real { unit 'W'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def FrequencyValue :> Real { unit 'Hz'; }
    value def RotationalSpeed :> Real { unit 'rev/min'; }
    value def TemperatureValue :> Real { unit 'K'; }
    value def EfficiencyValue :> Real { unit '%'; }

    attribute def TargetDO {
        attribute setpoint : DOConcentration = 2.0 [mg/L];
        attribute tolerance : DOConcentration = 0.2 [mg/L];
    }

    // ---- Item definitions ----
    item def Wastewater {
        attribute temperature : TemperatureValue;
        attribute doLevel : DOConcentration;
    }
    item def AtmosphericAir {
        attribute pressure : PressureValue = 101325 [Pa];
    }
    item def CompressedAir {
        attribute pressure : PressureValue;
        attribute flowRate : VolumetricFlowRate;
    }
    item def PressurizedWater {
        attribute pressure : PressureValue;
        attribute flowRate : VolumetricFlowRate;
    }
    item def AirWaterMixture {
        attribute airFraction : Real;
        attribute pressure : PressureValue;
    }
    item def FineBubblePlume {
        attribute bubbleDiameter : Real; // in m
        attribute flowRate : VolumetricFlowRate;
    }
    item def DOReading {
        attribute value : DOConcentration;
        attribute timestamp : Real;
    }
    item def ControlCommand {
        attribute pumpEnabled : Boolean;
        attribute compressorEnabled : Boolean;
        attribute compressorSpeed : RotationalSpeed;
    }
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute maxPower : PowerValue;
    }

    // ---- Port definitions ----
    port def FluidInPort {
        out item : Wastewater;
    }
    port def WaterInPort {
        in item : Wastewater;
    }
    port def WaterOutPort {
        out item : PressurizedWater;
    }
    port def AirInPort {
        in item : AtmosphericAir;
    }
    port def AirOutPort {
        out item : CompressedAir;
    }
    port def NozzleWaterInPort {
        in item : PressurizedWater;
    }
    port def NozzleAirInPort {
        in item : CompressedAir;
    }
    port def NozzleOutPort {
        out item : FineBubblePlume;
    }
    port def BasinInPort {
        in item : FineBubblePlume;
    }
    port def BasinSamplePort {
        out item : Wastewater;
    }
    port def DOSensorInPort {
        in item : Wastewater;
    }
    port def DOSensorOutPort {
        out item : DOReading;
    }
    port def ControlInPort {
        in item : DOReading;
    }
    port def ControlOutPort {
        out item : ControlCommand;
    }
    port def PumpControlPort {
        in item : ControlCommand;
    }
    port def CompressorControlPort {
        in item : ControlCommand;
    }
    port def ElectricalInPort {
        in item : ElectricalPower;
    }

    // ---- Requirements ----
    requirement def OxygenTransferRequirement {
        attribute minDO : DOConcentration = 2.0 [mg/L];
        subject basin : AerationBasin;
        require { basin.dissolvedOxygen >= minDO }
    }

    requirement def EnergyEfficiencyRequirement {
        attribute maxPower : PowerValue = 75000 [W];
        subject system : JetAerationSystem;
        require { system.totalPowerDraw <= maxPower }
    }

    requirement def MixingRequirement {
        attribute minAirFraction : Real = 0.15;
        subject nozzle : JetNozzle;
        require { nozzle.mixture.airFraction >= minAirFraction }
    }

    // ---- Part definitions ----

    part def WaterPump {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port control : PumpControlPort;
        port power : ElectricalInPort;

        attribute ratedFlow : VolumetricFlowRate = 0.25 [m3/s];
        attribute ratedPressure : PressureValue = 300000 [Pa];
        attribute ratedPower : PowerValue = 30000 [W];
        attribute efficiency : EfficiencyValue = 75 [%];
        attribute enabled : Boolean = true;

        action def Pressurize {
            in water : Wastewater;
            out pressurized : PressurizedWater;
            perform {
                pressurized.pressure := ratedPressure;
                pressurized.flowRate := ratedFlow;
            }
        }

        exhibit Pressurize;
    }

    part def AirCompressor {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port control : CompressorControlPort;
        port power : ElectricalInPort;

        attribute ratedFlow : VolumetricFlowRate = 0.10 [m3/s];
        attribute ratedPressure : PressureValue = 250000 [Pa];
        attribute ratedPower : PowerValue = 25000 [W];
        attribute speed : RotationalSpeed = 1800 [rev/min];
        attribute enabled : Boolean = true;

        action def Compress {
            in air : AtmosphericAir;
            out compressed : CompressedAir;
            perform {
                compressed.pressure := ratedPressure;
                compressed.flowRate := ratedFlow * (speed / 1800.0);
            }
        }

        exhibit Compress;
    }

    part def JetNozzle {
        port waterIn : NozzleWaterInPort;
        port airIn : NozzleAirInPort;
        port plumeOut : NozzleOutPort;

        attribute orificeDiameter : Real = 0.02 [m];
        attribute mixture : AirWaterMixture;

        action def MixAndDischarge {
            in water : PressurizedWater;
            in air : CompressedAir;
            out plume : FineBubblePlume;
            perform {
                plume.bubbleDiameter := 0.001;
                plume.flowRate := water.flowRate + air.flowRate;
            }
        }

        exhibit MixAndDischarge;
    }

    part def AerationBasin {
        port plumeIn : BasinInPort;
        port sample : BasinSamplePort;

        attribute volume : Real = 1500 [m3];
        attribute dissolvedOxygen : DOConcentration = 0.5 [mg/L];
        attribute targetDO : DOConcentration = 2.0 [mg/L];

        action def TransferOxygen {
            in plume : FineBubblePlume;
            inout basinDO : DOConcentration;
            perform {
                basinDO := basinDO + plume.flowRate * 0.0001;
            }
        }

        exhibit TransferOxygen;
    }

    part def DOSensor {
        port sampleIn : DOSensorInPort;
        port readingOut : DOSensorOutPort;

        attribute samplingInterval : Real = 5 [s];
        attribute lastReading : DOConcentration;

        action def Measure {
            in sample : Wastewater;
            out reading : DOReading;
            perform {
                reading.value := sample.doLevel;
                reading.timestamp := 0.0;
            }
        }

        exhibit Measure;
    }

    part def ControlSystem {
        port readingIn : ControlInPort;
        port commandOut : ControlOutPort;

        attribute target : TargetDO;
        attribute currentDO : DOConcentration;
        attribute lastCommand : ControlCommand;

        state machine ControlBehavior {
            state Off;
            state Monitoring;
            state IncreasingAeration;
            state DecreasingAeration;
            state Alarm;

            transition init off_init { from Off to Monitoring; }

            transition monitor_to_increase {
                from Monitoring to IncreasingAeration;
                when { currentDO < target.setpoint - target.tolerance }
            }
            transition monitor_to_decrease {
                from Monitoring to DecreasingAeration;
                when { currentDO > target.setpoint + target.tolerance }
            }
            transition increase_to_monitor {
                from IncreasingAeration to Monitoring;
                when { currentDO >= target.setpoint - target.tolerance }
            }
            transition decrease_to_monitor {
                from DecreasingAeration to Monitoring;
                when { currentDO <= target.setpoint + target.tolerance }
            }
            transition any_to_alarm {
                from Monitoring to Alarm;
                when { currentDO < 0.1 [mg/L] }
            }

            entry Off {
                lastCommand.pumpEnabled := false;
                lastCommand.compressorEnabled := false;
                lastCommand.compressorSpeed := 0 [rev/min];
            }
            entry Monitoring {
                lastCommand.pumpEnabled := true;
                lastCommand.compressorEnabled := true;
                lastCommand.compressorSpeed := 1800 [rev/min];
            }
            entry IncreasingAeration {
                lastCommand.pumpEnabled := true;
                lastCommand.compressorEnabled := true;
                lastCommand.compressorSpeed := 2400 [rev/min];
            }
            entry DecreasingAeration {
                lastCommand.pumpEnabled := true;
                lastCommand.compressorEnabled := true;
                lastCommand.compressorSpeed := 1200 [rev/min];
            }
            entry Alarm {
                lastCommand.pumpEnabled := true;
                lastCommand.compressorEnabled := true;
                lastCommand.compressorSpeed := 3000 [rev/min];
            }
        }

        exhibit ControlBehavior;
    }

    part def ElectricalSupply {
        port pumpPower : ElectricalInPort;
        port compressorPower : ElectricalInPort;

        attribute voltage : VoltageValue = 480 [V];
        attribute frequency : FrequencyValue = 60 [Hz];
        attribute maxPower : PowerValue = 100000 [W];

        action def SupplyPower {
            out toPump : ElectricalPower;
            out toCompressor : ElectricalPower;
            perform {
                toPump.voltage := voltage;
                toPump.frequency := frequency;
                toPump.maxPower := 40000 [W];
                toCompressor.voltage := voltage;
                toCompressor.frequency := frequency;
                toCompressor.maxPower := 35000 [W];
            }
        }

        exhibit SupplyPower;
    }

    // ---- Top-level system ----
    part def JetAerationSystem {
        port intake : FluidInPort;

        part waterPump : WaterPump {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            port control : PumpControlPort;
            port power : ElectricalInPort;
        }
        part airCompressor : AirCompressor {
            port airIn : AirInPort;
            port airOut : AirOutPort;
            port control : CompressorControlPort;
            port power : ElectricalInPort;
        }
        part jetNozzle : JetNozzle {
            port waterIn : NozzleWaterInPort;
            port airIn : NozzleAirInPort;
            port plumeOut : NozzleOutPort;
        }
        part aerationBasin : AerationBasin {
            port plumeIn : BasinInPort;
            port sample : BasinSamplePort;
        }
        part doSensor : DOSensor {
            port sampleIn : DOSensorInPort;
            port readingOut : DOSensorOutPort;
        }
        part controlSystem : ControlSystem {
            port readingIn : ControlInPort;
            port commandOut : ControlOutPort;
        }
        part electricalSupply : ElectricalSupply {
            port pumpPower : ElectricalInPort;
            port compressorPower : ElectricalInPort;
        }

        attribute totalPowerDraw : PowerValue;

        requirement oxyReq : OxygenTransferRequirement {
            subject = aerationBasin;
        }
        requirement energyReq : EnergyEfficiencyRequirement {
            subject = JetAerationSystem::this;
        }
        requirement mixReq : MixingRequirement {
            subject = jetNozzle;
        }

        connection waterPumpToNozzle connect waterPump.waterOut to jetNozzle.waterIn;
        connection compressorToNozzle connect airCompressor.airOut to jetNozzle.airIn;
        connection nozzleToBasin connect jetNozzle.plumeOut to aerationBasin.plumeIn;
        connection basinToSensor connect aerationBasin.sample to doSensor.sampleIn;
        connection sensorToController connect doSensor.readingOut to controlSystem.readingIn;
        connection controllerToPump connect controlSystem.commandOut to waterPump.control;
        connection controllerToCompressor connect controlSystem.commandOut to airCompressor.control;
        connection supplyToPump connect electricalSupply.pumpPower to waterPump.power;
        connection supplyToCompressor connect electricalSupply.compressorPower to airCompressor.power;

        flow from waterPump.waterOut to jetNozzle.waterIn of PressurizedWater;
        flow from airCompressor.airOut to jetNozzle.airIn of CompressedAir;
        flow from jetNozzle.plumeOut to aerationBasin.plumeIn of FineBubblePlume;
        flow from aerationBasin.sample to doSensor.sampleIn of Wastewater;
        flow from doSensor.readingOut to controlSystem.readingIn of DOReading;
        flow from controlSystem.commandOut to waterPump.control of ControlCommand;
        flow from controlSystem.commandOut to airCompressor.control of ControlCommand;
        flow from electricalSupply.pumpPower to waterPump.power of ElectricalPower;
        flow from electricalSupply.compressorPower to airCompressor.power of ElectricalPower;
    }
}
