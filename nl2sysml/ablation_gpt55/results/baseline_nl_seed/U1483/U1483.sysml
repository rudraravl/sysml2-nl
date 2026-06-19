package ResistorBasedCurrentLimiterModel {
    import ScalarValues::*;

    attribute def Voltage_V :> ScalarValues::Real {
        doc /* Unit: volt (V). */
    }

    attribute def Current_A :> ScalarValues::Real {
        doc /* Unit: ampere (A). */
    }

    attribute def Resistance_ohm :> ScalarValues::Real {
        doc /* Unit: ohm. */
    }

    attribute def Power_W :> ScalarValues::Real {
        doc /* Unit: watt (W). */
    }

    attribute def Energy_J :> ScalarValues::Real {
        doc /* Unit: joule (J). */
    }

    attribute def Temperature_degC :> ScalarValues::Real {
        doc /* Unit: degree Celsius. */
    }

    attribute def ThermalResistance_degC_per_W :> ScalarValues::Real {
        doc /* Unit: degree Celsius per watt. */
    }

    attribute def Time_s :> ScalarValues::Real {
        doc /* Unit: second (s). */
    }

    attribute def Percent :> ScalarValues::Real {
        doc /* Unit: percent (%). */
    }

    item def ConductiveCurrent {
        attribute current : Current_A;
        attribute voltage : Voltage_V;
    }

    item def ElectricalEnergy {
        attribute energy : Energy_J;
        attribute averagePower : Power_W;
    }

    item def ThermalEnergy {
        attribute heat : Energy_J;
        attribute heatRate : Power_W;
        attribute temperature : Temperature_degC;
    }

    item def ElectricSignal {
        attribute highLevelVoltage : Voltage_V;
        attribute lowLevelVoltage : Voltage_V;
        attribute sourceCurrentLimit : Current_A;
    }

    port def ElectricalTerminal {
        inout item conduction : ConductiveCurrent;
        attribute terminalVoltage : Voltage_V;
        attribute terminalCurrent : Current_A;
    }

    port def ThermalPort {
        inout item heatFlow : ThermalEnergy;
        attribute portTemperature : Temperature_degC;
    }

    constraint def OhmsLaw {
        in voltageDrop : Voltage_V;
        in current : Current_A;
        in resistance : Resistance_ohm;
        constraint { voltageDrop == current * resistance }
    }

    constraint def ResistorPowerLaw {
        in voltageDrop : Voltage_V;
        in current : Current_A;
        in dissipatedPower : Power_W;
        constraint { dissipatedPower == voltageDrop * current }
    }

    constraint def SeriesCircuitLaw {
        in sourceVoltage : Voltage_V;
        in loadCurrent : Current_A;
        in resistorResistance : Resistance_ohm;
        in loadResistance : Resistance_ohm;
        constraint { sourceVoltage == loadCurrent * (resistorResistance + loadResistance) }
    }

    constraint def ThermalRiseLaw {
        in ambientTemperature : Temperature_degC;
        in thermalResistance : ThermalResistance_degC_per_W;
        in dissipatedPower : Power_W;
        in bodyTemperature : Temperature_degC;
        constraint { bodyTemperature == ambientTemperature + thermalResistance * dissipatedPower }
    }

    action def LimitCurrentAndDissipatePower {
        in availableVoltage : Voltage_V;
        in seriesResistance : Resistance_ohm;
        in loadEquivalentResistance : Resistance_ohm;
        out deliveredCurrent : Current_A;
        out loadVoltage : Voltage_V;
        out resistorVoltageDrop : Voltage_V;
        out heatPower : Power_W;

        constraint circuitBehavior : SeriesCircuitLaw {
            in sourceVoltage = availableVoltage;
            in loadCurrent = deliveredCurrent;
            in resistorResistance = seriesResistance;
            in loadResistance = loadEquivalentResistance;
        }

        constraint resistorBehavior : OhmsLaw {
            in voltageDrop = resistorVoltageDrop;
            in current = deliveredCurrent;
            in resistance = seriesResistance;
        }

        constraint heatGeneration : ResistorPowerLaw {
            in voltageDrop = resistorVoltageDrop;
            in current = deliveredCurrent;
            in dissipatedPower = heatPower;
        }
    }

    action def MonitorThermalMargin {
        in bodyTemperature : Temperature_degC;
        in maximumBodyTemperature : Temperature_degC;
        out overTemperatureDetected : ScalarValues::Boolean;
    }

    state def ResistorOperatingModes {
        state deenergized;
        state conducting;
        state currentLimited;
        state thermalWarning;
        state failedOpen;

        transition initialize
            then deenergized;

        transition applyInputVoltage
            first deenergized
            then conducting;

        transition enterCurrentLimitedOperation
            first conducting
            then currentLimited;

        transition detectThermalWarning
            first currentLimited
            then thermalWarning;

        transition coolToNormalOperation
            first thermalWarning
            then currentLimited;

        transition openCircuitFailure
            first thermalWarning
            then failedOpen;

        transition removeInputVoltageFromConducting
            first conducting
            then deenergized;

        transition removeInputVoltageFromCurrentLimited
            first currentLimited
            then deenergized;
    }

    part def Resistor {
        doc /* A resistor is a passive electrical component whose high-level primary function is to oppose current flow, create a voltage drop proportional to current, and convert the associated electrical energy into thermal energy. */

        port positive : ElectricalTerminal;
        port negative : ElectricalTerminal;
        port thermal : ThermalPort;

        attribute nominalResistance : Resistance_ohm = 1000.0;
        attribute tolerance : Percent = 5.0;
        attribute maximumPower : Power_W = 0.25;
        attribute ratedAmbientTemperature : Temperature_degC = 25.0;
        attribute maximumBodyTemperature : Temperature_degC = 125.0;
        attribute thermalResistanceToAmbient : ThermalResistance_degC_per_W = 250.0;
        attribute voltageDrop : Voltage_V;
        attribute currentThrough : Current_A;
        attribute dissipatedPower : Power_W;
        attribute bodyTemperature : Temperature_degC;

        constraint ohmicBehavior : OhmsLaw {
            in voltageDrop = voltageDrop;
            in current = currentThrough;
            in resistance = nominalResistance;
        }

        constraint electricalToThermalConversion : ResistorPowerLaw {
            in voltageDrop = voltageDrop;
            in current = currentThrough;
            in dissipatedPower = dissipatedPower;
        }

        constraint thermalBehavior : ThermalRiseLaw {
            in ambientTemperature = ratedAmbientTemperature;
            in thermalResistance = thermalResistanceToAmbient;
            in dissipatedPower = dissipatedPower;
            in bodyTemperature = bodyTemperature;
        }

        state mode : ResistorOperatingModes;
    }

    part def ProtectedLoad {
        doc /* The protected load consumes the limited electrical current provided through the series resistor. */

        port positive : ElectricalTerminal;
        port negative : ElectricalTerminal;

        attribute equivalentResistance : Resistance_ohm = 2000.0;
        attribute minimumOperatingVoltage : Voltage_V = 3.0;
        attribute maximumAllowedCurrent : Current_A = 0.010;
        attribute receivedVoltage : Voltage_V;
        attribute receivedCurrent : Current_A;
        attribute consumedPower : Power_W;

        constraint loadPower : ResistorPowerLaw {
            in voltageDrop = receivedVoltage;
            in current = receivedCurrent;
            in dissipatedPower = consumedPower;
        }
    }

    part def AmbientEnvironment {
        port thermalIn : ThermalPort;

        attribute ambientTemperature : Temperature_degC = 25.0;
        attribute acceptedHeatPower : Power_W;
    }

    part def ResistorBasedCurrentLimiter {
        doc /* High-level primary function: accept an input voltage and deliver electrical power to a load through a resistor so that the resistor limits current, establishes a predictable voltage drop, and safely dissipates excess electrical power as heat. */

        port input : ElectricalTerminal;
        port output : ElectricalTerminal;
        port return : ElectricalTerminal;
        port signalSense : ElectricalTerminal;

        part seriesResistor : Resistor;
        part protectedLoad : ProtectedLoad;
        part enclosure : AmbientEnvironment;

        attribute inputVoltage : Voltage_V = 12.0;
        attribute outputVoltage : Voltage_V;
        attribute loadCurrent : Current_A;
        attribute resistorVoltageDrop : Voltage_V;
        attribute resistorHeatPower : Power_W;
        attribute allowableLoadCurrent : Current_A = 0.010;
        attribute allowableResistorPower : Power_W = 0.25;
        attribute responseTime : Time_s = 0.001;

        connect input to seriesResistor.positive;
        connect seriesResistor.negative to output;
        connect output to protectedLoad.positive;
        connect protectedLoad.negative to return;
        connect signalSense to output;
        connect seriesResistor.thermal to enclosure.thermalIn;

        constraint seriesCircuitBehavior : SeriesCircuitLaw {
            in sourceVoltage = inputVoltage;
            in loadCurrent = loadCurrent;
            in resistorResistance = seriesResistor.nominalResistance;
            in loadResistance = protectedLoad.equivalentResistance;
        }

        constraint resistorOhmicBehavior : OhmsLaw {
            in voltageDrop = resistorVoltageDrop;
            in current = loadCurrent;
            in resistance = seriesResistor.nominalResistance;
        }

        constraint resistorHeatBehavior : ResistorPowerLaw {
            in voltageDrop = resistorVoltageDrop;
            in current = loadCurrent;
            in dissipatedPower = resistorHeatPower;
        }

        perform action regulateLoadCurrent : LimitCurrentAndDissipatePower;
        perform action monitorThermalMargin : MonitorThermalMargin;

        state operatingMode : ResistorOperatingModes;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The resistor-based system shall perform the high-level primary function of limiting current to a protected load by placing a resistor in series with the load, producing a predictable voltage drop, and dissipating excess electrical energy as heat. */

        subject system : ResistorBasedCurrentLimiter;

        require constraint positiveResistance {
            system.seriesResistor.nominalResistance > 0.0
        }

        require constraint limitedLoadCurrent {
            system.loadCurrent <= system.allowableLoadCurrent
        }
    }

    requirement def OhmicBehaviorRequirement {
        doc /* The series resistor shall obey the high-level ohmic relationship between voltage drop, current, and resistance during normal conducting operation. */

        subject resistor : Resistor;

        require constraint ohmicRelationship {
            resistor.voltageDrop == resistor.currentThrough * resistor.nominalResistance
        }
    }

    requirement def PowerSafetyRequirement {
        doc /* The resistor-based system shall keep resistor heat dissipation within the resistor power rating during intended operation. */

        subject system : ResistorBasedCurrentLimiter;

        require constraint safeResistorPower {
            system.resistorHeatPower <= system.allowableResistorPower
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The resistor body temperature shall remain below the maximum body temperature when the system operates in current-limited mode. */

        subject resistor : Resistor;

        require constraint safeBodyTemperature {
            resistor.bodyTemperature <= resistor.maximumBodyTemperature
        }
    }

    part currentLimiter : ResistorBasedCurrentLimiter;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = currentLimiter;
    }

    requirement ohmicBehavior : OhmicBehaviorRequirement {
        subject resistor = currentLimiter.seriesResistor;
    }

    requirement powerSafety : PowerSafetyRequirement {
        subject system = currentLimiter;
    }

    requirement thermalSafety : ThermalSafetyRequirement {
        subject resistor = currentLimiter.seriesResistor;
    }
}
