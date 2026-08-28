package HouseholdRefrigerator {
    import ScalarValues::*;
    import ISQ::*;
    import ISQUnit::*;

    // ---- Value types with units ----
    value def TemperatureValue :> Real { unit "°C"; }
    value def PressureValue :> Real { unit "Pa"; }
    value def MassFlowValue :> Real { unit "kg/s"; }
    value def PowerValue :> Real { unit "W"; }
    value def VoltageValue :> Real { unit "V"; }
    value def VolumeFlowValue :> Real {m3/s"; }
    value def HeatFlowValue :> Real { unit "W"; }
    value def DurationValue :> Real { unit "s"; }

    // ---- Items ----
    item def Refrigerant;
    item def Air;
    item def ElectricalEnergy;
    item def ControlSignal;

    // ---- Signal attributes ----
    attribute def TempReading { value : TemperatureValue; }
    attribute def DoorStatus { isOpen : Boolean; }
    attribute def Setpoint { target : TemperatureValue; }
    attribute def Command { on : Boolean; }

    // ---- Ports ----
    port def RefrigerantPort {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : MassFlowValue;
        item ref refrigerant : Refrigerant;
    }
    port def AirPort {
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowValue;
        item ref air : Air;
    }
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
        item ref energy : ElectricalEnergy;
    }
    port def TempSignalPort { attribute reading : TempReading; }
    port def DoorSignalPort { attribute status : DoorStatus; }
    port def CommandSignalPort { attribute command : Command; }

    // ---- Requirements ----
    requirement def PreservationRequirement {
        doc /* The refrigerator shall preserve perishable food by maintaining a stable low internal temperature. */
        attribute targetTemp : TemperatureValue = 4.0;
        attribute maxTemp : TemperatureValue = 7.0;
        attribute minTemp : TemperatureValue = 1.0;
        attribute internalTemp : TemperatureValue;
        require constraint { internalTemp <= maxTemp and internalTemp >= minTemp }
    }

    requirement def EnergySavingRequirement {
        doc /* The cooling cycle shall not run while the door is open. */
        attribute doorOpen : Boolean;
        attribute compressorOn : Boolean;
        require constraint { doorOpen implies not compressorOn }
    }

    requirement def HeatRemovalRequirement {
        doc /* The system shall actively move heat from the interior to the external environment. */
        attribute coolingCapacity : PowerValue = 150.0;
        attribute heatRemoved : HeatFlowValue;
        require constraint { heatRemoved >= coolingCapacity }
    }

    requirement def PowerDistributionRequirement {
        doc /* The power supply shall distribute electrical energy to controller, compressor, and fans. */
        attribute inputVoltage : VoltageValue = 120.0;
        attribute controllerVoltage : VoltageValue = 12.0;
        attribute compressorVoltage : VoltageValue = 120.0;
        attribute fanVoltage : VoltageValue = 12.0;
        require constraint { inputVoltage >= 110.0 and inputVoltage <= 130.0 }
    }

    // ---- Component part definitions ----
    part def Compressor {
        port in inlet : RefrigerantPort;
        port out outlet : RefrigerantPort;
        port in power : ElectricalPort;
        port in cmd : CommandSignalPort;
        attribute powerConsumption : PowerValue = 120.0;
        attribute isRunning : Boolean = false;
        attribute outputPressure : PressureValue = 1.2e6;

        action def Pressurize {
            in ref gasIn : Refrigerant;
            out ref gasOut : Refrigerant;
            attribute inputPressure : PressureValue;
            attribute outputPressure : PressureValue;
        }
    }

    part def Condenser {
        port in inlet : RefrigerantPort;
        port out outlet : RefrigerantPort;
        port in airIn : AirPort;
        port out airOut : AirPort;
        attribute heatDissipation : HeatFlowValue = 180.0;
        attribute condensationPressure : PressureValue = 1.15e6;
        attribute condensationTemp : TemperatureValue = 35.0;
    }

    part def ExpansionValve {
        port in inlet : RefrigerantPort;
        port out outlet : RefrigerantPort;
        attribute pressureDrop : PressureValue = 1.1e6;
        attribute outputPressure : PressureValue = 1.0e5;
        attribute outputTemp : TemperatureValue = -10.0;
    }

    part def Evaporator {
        port in inlet : RefrigerantPort;
        port out outlet : RefrigerantPort;
        port in airIn : AirPort;
        port out airOut : AirPort;
        attribute coolingCapacity : HeatFlowValue = 150.0;
        attribute evaporationTemp : TemperatureValue = -5.0;
        attribute evaporationPressure : PressureValue = 1.0e5;
    }

    part def Fan {
        port in power : ElectricalPort;
        port in cmd : CommandSignalPort;
        port in airIn : AirPort;
        port out airOut : AirPort;
        attribute flowRate : VolumeFlowValue = 0.05;
        attribute powerConsumption : PowerValue = 8.0;
        attribute isRunning : Boolean = false;
    }

    part def TemperatureSensor {
        port out reading : TempSignalPort;
        attribute measuredTemp : TemperatureValue = 4.0;
        attribute accuracy : TemperatureValue = 0.5;
    }

    part def DoorSensor {
        port out status : DoorSignalPort;
        attribute isOpen : Boolean = false;
    }

    part def Controller {
        port in tempInput : TempSignalPort;
        port in doorInput : DoorSignalPort;
        port in power : ElectricalPort;
        port out compressorCmd : CommandSignalPort;
        port out condenserFanCmd : CommandSignalPort;
        port out evaporatorFanCmd : CommandSignalPort;
        attribute setpoint : TemperatureValue = 4.0;
        attribute hysteresis : TemperatureValue = 1.5;
        attribute currentTemp : TemperatureValue;
        attribute doorOpen : Boolean;

        state def ControlBehavior {
            attribute currentTemp : TemperatureValue;
            attribute doorOpen : Boolean;
            attribute setpoint : TemperatureValue = 4.0;
            attribute hysteresis : TemperatureValue = 1.5;

            state Idle {
                entry action { /* compressor off, fans off */ }
            }
            state Cooling {
                entry action { /* compressor on, condenser fan on, evaporator fan on */ }
            }
            state DoorOpen {
                entry action { /* compressor off, evaporator fan off, condenser fan off */ }
            }

            transition Idle to Cooling
                when { currentTemp > setpoint + hysteresis and not doorOpen }
                if { not doorOpen };
            transition Cooling to Idle
                when { currentTemp <= setpoint }
                if { not doorOpen };
            transition Idle to DoorOpen
                when { doorOpen };
            transition Cooling to DoorOpen
                when { doorOpen };
            transition DoorOpen to Idle
                when { not doorOpen and currentTemp <= setpoint + hysteresis };
            transition DoorOpen to Cooling
                when { not doorOpen and currentTemp > setpoint + hysteresis };
        }
    }

    part def PowerSupply {
        port out controllerPower : ElectricalPort;
        port out compressorPower : ElectricalPort;
        port out condenserFanPower : ElectricalPort;
        port out evaporatorFanPower : ElectricalPort;
        attribute inputVoltage : VoltageValue = 120.0;
        attribute outputControlVoltage : VoltageValue = 12.0;
        attribute outputCompressorVoltage : VoltageValue = 120.0;
        attribute outputFanVoltage : VoltageValue = 12.0;
        attribute maxPower : PowerValue = 300.0;
    }

    part def InteriorCompartment {
        port in coldAirIn : AirPort;
        port out warmAirOut : AirPort;
        attribute volume : Real = 0.5;
        attribute internalTemp : TemperatureValue = 4.0;
        attribute thermalMass : Real = 50.0;
    }

    part def InsulatedStructure {
        port in externalHeat : AirPort;
        attribute insulationRValue : Real = 5.0;
        attribute wallThickness : Real = 0.06;
        attribute heatLeakage : HeatFlowValue = 15.0;
    }

    // ---- Top-level refrigerator system ----
    part refrigerator :> PreservationRequirement, EnergySavingRequirement, HeatRemovalRequirement, PowerDistributionRequirement {
        attribute internalTemp : TemperatureValue = 4.0;
        attribute heatRemoved : HeatFlowValue = 150.0;

        part compressor : Compressor {
            attribute isRunning = false;
        }
        part condenser : Condenser;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;
        part condenserFan : Fan;
        part evaporatorFan : Fan;
        part controller : Controller;
        part temperatureSensor : TemperatureSensor;
        part doorSensor : DoorSensor;
        part powerSupply : PowerSupply;
        part interior : InteriorCompartment;
        part structure : InsulatedStructure;

        // Refrigerant closed loop
        flow connection refrigerantFlow1
            from compressor.outlet to condenser.inlet;
        flow connection refrigerantFlow2
            from condenser.outlet to expansionValve.inlet;
        flow connection refrigerantFlow3
            from expansionValve.outlet to evaporator.inlet;
        flow connection refrigerantFlow4
            from evaporator.outlet to compressor.inlet;

        // Condenser cooling air path
        flow connection condenserAirIn
            from structure.externalHeat to condenserFan.airIn;
        flow connection condenserAirThrough
            from condenserFan.airOut to condenser.airIn;
        flow connection condenserAirOut
            from condenser.airOut to structure.externalHeat;

        // Evaporator interior air path
        flow connection interiorAirToEvap
            from interior.warmAirOut to evaporatorFan.airIn;
        flow connection fanToEvap
            from evaporatorFan.airOut to evaporator.airIn;
        flow connection coldAirToInterior
            from evaporator.airOut to interior.coldAirIn;

        // Electrical distribution
        connection powerToController
            from powerSupply.controllerPower to controller.power;
        connection powerToCompressor
            from powerSupply.compressorPower to compressor.power;
        connection powerToCondenserFan
            from powerSupply.condenserFanPower to condenserFan.power;
        connection powerToEvaporatorFan
            from powerSupply.evaporatorFanPower to evaporatorFan.power;

        // Control signals
        connection tempToController
            from temperatureSensor.reading to controller.tempInput;
        connection doorToController
            from doorSensor.status to controller.doorInput;
        connection cmdToCompressor
            from controller.compressorCmd to compressor.cmd;
        connection cmdToCondenserFan
            from controller.condenserFanCmd to condenserFan.cmd;
        connection cmdToEvaporatorFan
            from controller.evaporatorFanCmd to evaporatorFan.cmd;

        // Refrigeration cycle behavior
        action def RefrigerationCycle {
            in ref lowPressureGas : Refrigerant;
            out ref highPressureGas : Refrigerant;
            attribute heatAbsorbed : HeatFlowValue;
            attribute heatRejected : HeatFlowValue;

            action compress : Compressor::Pressurize {
                in ref gasIn = lowPressureGas;
                out ref gasOut;
            }
            action condense {
                in ref gasIn = compress.gasOut;
                out ref liquidOut;
                attribute rejectedHeat : HeatFlowValue;
            }
            action expand {
                in ref liquidIn = condense.liquidOut;
                out ref coldMistOut;
            }
            action evaporate {
                in ref coldMistIn = expand.coldMistOut;
                out ref lowPressureGasOut;
                attribute absorbedHeat : HeatFlowValue;
            }
            succession compress then condense then expand then evaporate;
        }
    }
}
