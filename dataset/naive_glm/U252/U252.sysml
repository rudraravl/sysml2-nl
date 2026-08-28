package Hydrocollator {

    import ScalarValues::*;

    // ================================================================
    // Value Types
    // ================================================================

    valueType TemperatureC :> Real {
        doc "Temperature in degrees Celsius (°C).";
    }

    valueType PowerW :> Real {
        doc "Electric power in watts (W).";
    }

    valueType VolumeL :> Real {
        doc "Volume in liters (L).";
    }

    valueType MassKg :> Real {
        doc "Mass in kilograms (kg).";
    }

    valueType TimeS :> Real {
        doc "Time in seconds (s).";
    }

    // ================================================================
    // Enumerations
    // ================================================================

    enum def IndicatorColor {
        red;
        green;
        off;
    }

    // ================================================================
    // Item Types
    // ================================================================

    item def Water {
        attribute temperature : TemperatureC;
        attribute volume : VolumeL;
    }

    item def MoistHeatPack {
        attribute identifier : String;
        attribute mass : MassKg;
        attribute isReady : Boolean = false;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def TemperatureReading {
        out temperature : TemperatureC;
    }

    port def HeaterCommand {
        in powerOn : Boolean;
    }

    port def IndicatorCommand {
        in color : IndicatorColor;
    }

    port def ThermalFlow {
        out heatFlow : Real;
    }

    port def PowerConnection {
        out voltage : Real;
        out current : Real;
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def TherapeuticTemperatureRequirement {
        doc
            "The system shall maintain the water temperature within the "
            "therapeutic range of 71°C to 79°C during the maintaining state.";
        subject system : HydrocollatorSystem;
        require {
            system.tank.water.temperature >= 71
            and system.tank.water.temperature <= 79
        }
    }

    requirement def InitialHeatingRequirement {
        doc
            "Upon power-on, the system shall enter the initial heating state "
            "and raise the water temperature to at least the lower bound of "
            "the therapeutic range (71°C).";
        subject system : HydrocollatorSystem;
        require {
            system.tank.water.temperature >= 71
        }
    }

    requirement def IndicatorLightRequirement {
        doc
            "The indicator light shall display red while the water "
            "temperature is below the therapeutic range, and green once "
            "the water temperature reaches the therapeutic range.";
        subject system : HydrocollatorSystem;
        require {
            (system.indicator.color == IndicatorColor::red
                implies system.tank.water.temperature < 71)
            and (system.indicator.color == IndicatorColor::green
                implies system.tank.water.temperature >= 71)
        }
    }

    requirement def PackCapacityRequirement {
        doc
            "The rack shall accommodate up to six moist heat packs "
            "simultaneously for immersion heating.";
        subject system : HydrocollatorSystem;
        require {
            system.tank.rack.slotCount == 6
        }
    }

    requirement def HeaterPowerRequirement {
        doc
            "The heating element shall be rated at sufficient power "
            "(>= 1000 W) to heat the full tank volume from ambient to "
            "therapeutic temperature within a reasonable time.";
        subject system : HydrocollatorSystem;
        require {
            system.tank.heatingElement.maxPower >= 1000
        }
    }

    requirement def SafetyOvertempRequirement {
        doc
            "The system shall not allow the water temperature to exceed "
            "82°C under any operating condition to prevent scalding hazards.";
        subject system : HydrocollatorSystem;
        require {
            system.tank.water.temperature <= 82
        }
    }

    requirement def TankInsulationRequirement {
        doc
            "The tank shall be insulated to minimize heat loss to the "
            "surrounding environment and maintain temperature stability.";
        subject system : HydrocollatorSystem;
        require {
            system.tank.isInsulated == true
        }
    }

    // ================================================================
    // Part Definitions – Sub-Components
    // ================================================================

    part def HeatingElement {
        doc
            "High-power electric immersion heating element that raises "
            "the water temperature inside the tank.";

        attribute maxPower : PowerW = 1500;
        attribute powerOn : Boolean = false;
        attribute efficiency : Real = 0.95;

        port heaterControl : HeaterCommand;
        port thermalOutput : ThermalFlow;
        port powerInput : PowerConnection;

        action def generateHeat {
            doc
                "Converts electrical energy to thermal energy when the "
                "heater is activated by the controller.";
            in command : Boolean;
            out heat : Real;
        }

        action def shutdown {
            doc "Safely de-energizes the heating element.";
        }
    }

    part def TemperatureSensor {
        doc
            "Continuously measures the water temperature inside the tank "
            "and provides the reading on its output port.";

        attribute accuracy : TemperatureC = 0.5;
        attribute samplingInterval : TimeS = 1.0;

        port reading : TemperatureReading;

        action def measure {
            doc
                "Reads the current water temperature and provides the "
                "reading on the output port.";
            in water : Water;
            out measuredTemp : TemperatureC;
        }
    }

    part def Rack {
        doc
            "Pack holder with multiple slots for immersing and heating "
            "moist heat packs simultaneously.";

        attribute slotCount : Integer = 6;
        ref item packs : MoistHeatPack[0..6];

        action def loadPack {
            doc "Loads a moist heat pack into a designated slot.";
            in pack : MoistHeatPack;
            in slotIndex : Integer;
        }

        action def unloadPack {
            doc "Removes a moist heat pack from a designated slot.";
            out pack : MoistHeatPack;
            in slotIndex : Integer;
        }
    }

    part def Tank {
        doc
            "Insulated water tank that holds a large volume of water, "
            "contains the heating element, and houses the pack rack.";

        attribute capacity : VolumeL = 28;
        attribute isInsulated : Boolean = true;
        item water : Water {
            :>> temperature = 25;
            :>> volume = 28;
        }

        port thermalInput : ThermalFlow;

        part heatingElement : HeatingElement;
        part rack : Rack;

        action def absorbHeat {
            doc
                "Absorbs thermal energy from the heating element, raising "
                "the water temperature uniformly.";
            in heat : Real;
            in currentWater : Water;
            out heatedWater : Water;
        }

        action def dissipateHeat {
            doc
                "Models natural heat loss from the tank to the surrounding "
                "environment through the insulation.";
            in currentWater : Water;
            out cooledWater : Water;
        }
    }

    part def Controller {
        doc
            "Thermostatic controller that compares the measured water "
            "temperature to the predefined therapeutic range and "
            "activates or deactivates the heating element accordingly.";

        attribute lowerLimit : TemperatureC = 71;
        attribute upperLimit : TemperatureC = 79;
        attribute safetyLimit : TemperatureC = 82;
        attribute currentTemp : TemperatureC = 25;
        attribute heaterActive : Boolean = false;
        attribute regulationMode : String = "idle";

        port tempInput : TemperatureReading;
        port heaterOutput : HeaterCommand;
        port indicatorOutput : IndicatorCommand;

        action def regulate {
            doc
                "Reads the measured temperature from the sensor, compares "
                "it to the therapeutic range, commands the heater on if "
                "below the lower limit, off if at or above the upper "
                "limit, and sets the indicator color accordingly.";
            in measuredTemp : TemperatureC;
            out heaterOn : Boolean;
            out indicatorColor : IndicatorColor;

            decision if measuredTemp < lowerLimit then {
                heaterOn = true;
                indicatorColor = IndicatorColor::red;
            } else if measuredTemp >= upperLimit then {
                heaterOn = false;
                indicatorColor = IndicatorColor::green;
            } else {
                heaterOn = false;
                indicatorColor = IndicatorColor::green;
            }
        }

        action def emergencyShutdown {
            doc
                "Triggers an immediate heater shutdown if the water "
                "temperature exceeds the safety limit.";
            in measuredTemp : TemperatureC;
        }
    }

    part def IndicatorLight {
        doc
            "Simple user interface indicator that shows red during the "
            "initial heat-up phase and green when the water has reached "
            "the target operating temperature.";

        attribute color : IndicatorColor = IndicatorColor::off;
        attribute isOperational : Boolean = true;

        port control : IndicatorCommand;

        action def updateDisplay {
            doc
                "Updates the indicator light color based on the "
                "controller command.";
            in commandedColor : IndicatorColor;
        }
    }

    // ================================================================
    // Top-Level System
    // ================================================================

    part def HydrocollatorSystem {
        doc
            "A thermostatically controlled water bath designed for heating "
            "and maintaining moist heat packs at a constant, safe, and "
            "therapeutic temperature for use in physical therapy and "
            "clinical settings.";

        attribute powerOn : Boolean = false;
        attribute isPluggedIn : Boolean = false;
        attribute ambientTemperature : TemperatureC = 25;

        // --- Sub-parts ---

        part tank : Tank {
            item water : Water {
                :>> temperature = 25;
                :>> volume = 28;
            }

            part heatingElement : HeatingElement {
                :>> maxPower = 1500;
                :>> powerOn = false;
            }

            part rack : Rack {
                :>> slotCount = 6;
            }
        }

        part sensor : TemperatureSensor {
            :>> accuracy = 0.5;
            :>> samplingInterval = 1.0;
        }

        part controller : Controller {
            :>> lowerLimit = 71;
            :>> upperLimit = 79;
            :>> safetyLimit = 82;
            :>> currentTemp = 25;
            :>> heaterActive = false;
        }

        part indicator : IndicatorLight {
            :>> color = IndicatorColor::off;
            :>> isOperational = true;
        }

        // --- Connections ---

        connection tempSensorToController
            connect sensor.reading to controller.tempInput;

        connection controllerToHeater
            connect controller.heaterOutput to tank.heatingElement.heaterControl;

        connection controllerToIndicator
            connect controller.indicatorOutput to indicator.control;

        connection heaterToTankThermal
            connect tank.heatingElement.thermalOutput to tank.thermalInput;

        // --- State Machine ---

        state machine HydrocollatorStates {
            doc
                "Governs the overall operational state of the Hydrocollator: "
                "powerOff when inactive, initialHeating upon startup, and "
                "maintaining once the therapeutic temperature range is "
                "reached.";

            state powerOff {
                doc "The system is inactive and not powered on.";

                entry {
                    indicator.color = IndicatorColor::off;
                    tank.heatingElement.powerOn = false;
                    controller.heaterActive = false;
                    controller.regulationMode = "idle";
                }
            }

            state initialHeating {
                doc
                    "The system has been powered on and is actively heating "
                    "the water from ambient temperature toward the "
                    "therapeutic range. The indicator shows red.";

                entry {
                    indicator.color = IndicatorColor::red;
                    controller.regulationMode = "initialHeating";
                    tank.heatingElement.powerOn = true;
                    controller.heaterActive = true;
                }

                do {
                    controller.regulate;
                }

                exit {
                    controller.regulationMode = "maintaining";
                }
            }

            state maintaining {
                doc
                    "The water has reached the therapeutic range "
                    "(71°C–79°C). The indicator shows green. The controller "
                    "cycles the heater on and off to maintain the "
                    "temperature within the prescribed range.";

                entry {
                    indicator.color = IndicatorColor::green;
                    controller.regulationMode = "maintaining";
                }

                do {
                    controller.regulate;
                }
            }

            // --- Transitions ---

            transition offToHeating
                powerOff -> initialHeating
                if { powerOn == true and isPluggedIn == true };

            transition heatingToMaintaining
                initialHeating -> maintaining
                if { tank.water.temperature >= 71 };

            transition maintainingToHeating
                maintaining -> initialHeating
                if { tank.water.temperature < 71 };

            transition heatingToOff
                initialHeating -> powerOff
                if { powerOn == false };

            transition maintainingToOff
                maintaining -> powerOff
                if { powerOn == false };
        }

        // --- Requirement Satisfaction ---

        satisfy TherapeuticTemperatureRequirement;
        satisfy InitialHeatingRequirement;
        satisfy IndicatorLightRequirement;
        satisfy PackCapacityRequirement;
        satisfy HeaterPowerRequirement;
        satisfy SafetyOvertempRequirement;
        satisfy TankInsulationRequirement;
    }
}
