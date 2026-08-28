package ConductivePolymerMaterial {

    import ScalarValues::*;

    // ================================================================
    // Value Types
    // ================================================================

    value type ConductivityValue :> Real {
        doc /* Electrical conductivity in S/m */;
    }

    value type DopingLevelValue :> Real {
        doc /* Doping level as mole fraction (0.0 to 1.0) */;
    }

    value type TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius */;
    }

    value type HumidityValue :> Real {
        doc /* Relative humidity percentage (0 to 100) */;
    }

    value type VoltageValue :> Real {
        doc /* Electric potential in volts */;
    }

    value type CurrentValue :> Real {
        doc /* Electric current in amperes */;
    }

    value type ChargeValue :> Real {
        doc /* Electric charge in coulombs */;
    }

    value type CarrierDensityValue :> Real {
        doc /* Charge carrier density in cm^-3 */;
    }

    value type MobilityValue :> Real {
        doc /* Carrier mobility in cm^2/(V*s) */;
    }

    value type ChainLengthValue :> Integer {
        doc /* Number of monomer repeat units in the polymer chain */;
    }

    value type CrystallinityValue :> Real {
        doc /* Degree of crystalline order (0 to 100 percent) */;
    }

    value type MolarMassValue :> Real {
        doc /* Molar mass in g/mol */;
    }

    value type DopantConcentrationValue :> Real {
        doc /* Dopant concentration in mol/L */;
    }

    value type TimeValue :> Real {
        doc /* Time duration in seconds */;
    }

    value type PowerValue :> Real {
        doc /* Power in watts */;
    }

    value type EnergyValue :> Real {
        doc /* Energy in joules */;
    }

    value type LengthValue :> Real {
        doc /* Length in nanometers */;
    }

    value type BandGapValue :> Real {
        doc /* Band gap energy in electron-volts */;
    }

    value type ResistanceValue :> Real {
        doc /* Electrical resistance in ohms */;
    }

    // ================================================================
    // Enumerations
    // ================================================================

    enumeration def DopingState {
        doc /* Conduction state of the material based on doping level */;
        undoped;
        lightlyDoped;
        heavilyDoped;
        degraded;
    }

    enumeration def DopantType {
        doc /* Types of chemical dopants for conductive polymers */;
        p_type;
        n_type;
        oxidative;
        reductive;
    }

    enumeration def CarrierType {
        doc /* Types of mobile charge carriers in the polymer matrix */;
        electron;
        hole;
        polaron;
        bipolaron;
        soliton;
    }

    enumeration def ConductionMechanismType {
        doc /* Physical mechanisms of electrical conduction in doped polymer */;
        hopping;
        bandTransport;
        variableRangeHopping;
        metallic;
        none;
    }

    enumeration def ConductorRole {
        doc /* Role of an electrode in the electrode pair */;
        anode;
        cathode;
    }

    enumeration def DegradationMode {
        doc /* Modes of material degradation */;
        thermalDegradation;
        oxidativeDegradation;
        hydrolyticDegradation;
        photodegradation;
        none;
    }

    // ================================================================
    // Item Definitions
    // ================================================================

    item def DopantChemical {
        doc /* Chemical species introduced during the doping process */;
        attribute type : DopantType;
        attribute molarMass : MolarMassValue;
        attribute electronAffinity : BandGapValue;
        attribute concentration : DopantConcentrationValue;
    }

    item def ChargeCarrier {
        doc /* Mobile charge carrier within the polymer matrix */;
        attribute carrierType : CarrierType;
        attribute charge : ChargeValue;
        attribute mobility : MobilityValue;
        attribute density : CarrierDensityValue;
    }

    item def MonomerUnit {
        doc /* Monomer repeat unit of the polymer chain */;
        attribute molarMass : MolarMassValue;
        attribute conjugationLength : LengthValue;
    }

    item def DopantMolecule {
        doc /* Individual dopant molecule positioned in the polymer matrix */;
        attribute type : DopantType;
        attribute position : Real {
            doc /* Fractional position along the chain (0.0 to 1.0) */;
        }
    }

    item def HeatFlux {
        doc /* Thermal energy transfer between components */;
        attribute magnitude : EnergyValue;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def ElectricalPort {
        doc /* Port for electrical connections carrying voltage and current */;
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        in item chargeCarrier : ChargeCarrier;
    }

    port def ChemicalPort {
        doc /* Port for chemical species transfer during doping */;
        in item dopant : DopantChemical;
    }

    port def EnvironmentalPort {
        doc /* Port for environmental monitoring and control signals */;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }

    port def ControlPort {
        doc /* Port for control commands to actuators */;
        attribute targetTemperature : TemperatureValue;
        attribute targetHumidity : HumidityValue;
        attribute heatingEnabled : Boolean;
        attribute coolingEnabled : Boolean;
        attribute humidifyingEnabled : Boolean;
        attribute dehumidifyingEnabled : Boolean;
    }

    port def StatusPort {
        doc /* Port for reporting measured conditions and material status */;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredHumidity : HumidityValue;
        attribute conductivity : ConductivityValue;
        attribute dopingState : DopingState;
        attribute mechanismType : ConductionMechanismType;
    }

    // ================================================================
    // Connection Definitions
    // ================================================================

    connection def ElectricalConnection {
        doc /* Connects two electrical ports for current flow */;
        end source : ElectricalPort;
        end target : ElectricalPort;
    }

    connection def ChemicalFlow {
        doc /* Connects chemical ports for dopant transfer */;
        end source : ChemicalPort;
        end target : ChemicalPort;
    }

    connection def EnvironmentalLink {
        doc /* Links environmental port from controller to material */;
        end controller : EnvironmentalPort;
        end material : EnvironmentalPort;
    }

    connection def ControlLink {
        doc /* Connects control signal port to actuator port */;
        end source : ControlPort;
        end target : ControlPort;
    }

    connection def StatusLink {
        doc /* Connects status reporting ports */;
        end source : StatusPort;
        end target : StatusPort;
    }

    // ================================================================
    // Component Part Definitions
    // ================================================================

    part def PolymerChain {
        doc /*
            The base polymer chain — a long-chain conjugated molecule
            whose structural properties (length and order) are crucial
            for its potential conductivity.
        */;

        attribute chainLength : ChainLengthValue;
        attribute crystallinity : CrystallinityValue;
        attribute molarMass : MolarMassValue;
        attribute bandGap : BandGapValue;
        attribute baseConductivity : ConductivityValue;
        item monomer : MonomerUnit;

        port chemicalEntry : ChemicalPort;
        port environmentInterface : EnvironmentalPort;
        port electrodeInterfaceA : ElectricalPort;
        port electrodeInterfaceB : ElectricalPort;

        part segments[0..*] {
            doc /* Subchains that form the polymer backbone */;
            attribute segmentLength : ChainLengthValue;
            attribute segmentCrystallinity : CrystallinityValue;
        }

        action verifyStructure {
            doc /* Verify polymer chain structural integrity and order */;
        }

        action calculateBaseConductivity {
            doc /* Compute intrinsic base conductivity of the undoped polymer */;
            out result : ConductivityValue;
        }
    }

    part def DopingAgent {
        doc /*
            Introduces a specific chemical dopant into the polymer,
            creating mobile charge carriers and enabling conduction.
        */;

        item dopantChemical : DopantChemical;
        attribute targetDopingLevel : DopingLevelValue;
        attribute currentDopingLevel : DopingLevelValue;
        attribute dopantFlowRate : DopantConcentrationValue;
        attribute dopingTime : TimeValue;

        port dopantOutput : ChemicalPort;
        port dopantControl : ControlPort;
        port dopantStatus : StatusPort;

        action applyDopant {
            doc /* Dispense dopant into the polymer at a controlled rate */;
            in target : DopingLevelValue;
            out result : DopingLevelValue;
        }

        action removeDopant {
            doc /* Reverse the doping process by removing dopant */;
            out result : DopingLevelValue;
        }

        action measureDopingLevel {
            doc /* Measure the achieved doping level after processing */;
            out level : DopingLevelValue;
        }
    }

    part def EnvironmentalController {
        doc /*
            Monitors and regulates ambient temperature and humidity
            to ensure the material performs reliably and does not degrade.
        */;

        attribute targetTemperature : TemperatureValue;
        attribute targetHumidity : HumidityValue;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredHumidity : HumidityValue;
        attribute maxOperatingTemp : TemperatureValue;
        attribute minOperatingTemp : TemperatureValue;
        attribute maxOperatingHumidity : HumidityValue;
        attribute minOperatingHumidity : HumidityValue;
        attribute tolerance : Real;
        attribute alarmActive : Boolean;

        port environmentOutput : EnvironmentalPort;
        port controlInput : ControlPort;
        port environmentStatus : StatusPort;

        part temperatureSensor {
            doc /* Temperature sensing element */;
            attribute reading : TemperatureValue;
            attribute accuracy : TemperatureValue;
        }

        part humiditySensor {
            doc /* Humidity sensing element */;
            attribute reading : HumidityValue;
            attribute accuracy : HumidityValue;
        }

        part heater {
            doc /* Heating element for temperature regulation */;
            attribute power : PowerValue;
            attribute active : Boolean;
        }

        part cooler {
            doc /* Cooling element for temperature regulation */;
            attribute power : PowerValue;
            attribute active : Boolean;
        }

        part humidifier {
            doc /* Humidification element */;
            attribute outputRate : HumidityValue;
            attribute active : Boolean;
        }

        part dehumidifier {
            doc /* Dehumidification element */;
            attribute outputRate : HumidityValue;
            attribute active : Boolean;
        }

        action regulateTemperature {
            doc /* Adjust heating or cooling to maintain target temperature */;
            in current : TemperatureValue;
            in target : TemperatureValue;
        }

        action regulateHumidity {
            doc /* Adjust humidification or dehumidification to maintain target humidity */;
            in current : HumidityValue;
            in target : HumidityValue;
        }

        action monitorConditions {
            doc /* Continuously monitor ambient temperature and humidity */;
            out temperature : TemperatureValue;
            out humidity : HumidityValue;
        }

        action triggerAlarm {
            doc /* Trigger an alarm when conditions exceed the safe operating range */;
        }
    }

    part def ConductionMechanism {
        doc /*
            Determines how well the material can transport an electrical charge.
            The conduction mechanism depends on the level of doping and
            the properties of the charge carriers created.
        */;

        attribute mechanismType : ConductionMechanismType;
        attribute effectiveConductivity : ConductivityValue;
        attribute carrierDensity : CarrierDensityValue;
        attribute carrierMobility : MobilityValue;
        item chargeCarrier : ChargeCarrier;
        attribute dopingState : DopingState;

        port mechanismStatus : StatusPort;

        action calculateConductivity {
            doc /* Compute effective conductivity from carrier density and mobility */;
            in density : CarrierDensityValue;
            in mobility : MobilityValue;
            out result : ConductivityValue;
        }

        action updateMechanismType {
            doc /* Update the conduction mechanism based on the current doping state */;
            in state : DopingState;
            out result : ConductionMechanismType;
        }
    }

    part def Electrode {
        doc /* Electrode for applying voltage across the polymer material */;
        attribute role : ConductorRole;
        attribute material : String;
        attribute surfaceArea : Real {
            doc /* Surface area in square centimeters */;
        }
        attribute contactResistance : ResistanceValue;
        attribute appliedVoltage : VoltageValue;
        attribute measuredCurrent : CurrentValue;

        port electricalContact : ElectricalPort;
        port polymerContact : ElectricalPort;
    }

    part def ChargeCarrierPopulation {
        doc /* Population of mobile charge carriers in the doped material */;
        attribute primaryCarrierType : CarrierType;
        attribute density : CarrierDensityValue;
        attribute mobility : MobilityValue;
        attribute totalCharge : ChargeValue;
        attribute recombinationRate : Real {
            doc /* Carrier recombination rate in s^-1 */;
        }
        attribute generationRate : Real {
            doc /* Carrier generation rate in s^-1 */;
        }

        item carriers[0..*] : ChargeCarrier;

        action generateCarriers {
            doc /* Generate charge carriers through the doping process */;
            in dopingLevel : DopingLevelValue;
            out density : CarrierDensityValue;
        }

        action recombineCarriers {
            doc /* Model carrier recombination losses */;
            in density : CarrierDensityValue;
            out reducedDensity : CarrierDensityValue;
        }
    }

    // ================================================================
    // State Machine Definition
    // ================================================================

    state machine def MaterialConductionState {
        doc /*
            State machine for the conductive polymer material operational state.
            The material can be an insulator (undoped), a semiconductor
            (lightly doped), metallic (heavily doped), or degraded under
            adverse environmental conditions.
        */;

        attribute currentDopingLevel : DopingLevelValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute maxSafeTemperature : TemperatureValue;
        attribute maxSafeHumidity : HumidityValue;
        attribute degradedFlag : Boolean;

        initial;

        state Undoped_Insulator {
            doc /* Material is undoped — acts as an electrical insulator */;
            entry {
                currentDopingLevel = 0.0;
            }
        }

        state LightlyDoped_Semiconductor {
            doc /* Material is lightly doped — acts as a semiconductor */;
        }

        state HeavilyDoped_Metallic {
            doc /* Material is heavily doped — behaves like a metal */;
        }

        state Degraded {
            doc /* Material has degraded — conductive properties lost entirely */;
            entry {
                degradedFlag = true;
            }
        }

        transition t_init
            from initial
            to Undoped_Insulator;

        transition t1
            from Undoped_Insulator
            to LightlyDoped_Semiconductor
            when currentDopingLevel > 0.0 and currentDopingLevel < 0.1;

        transition t2
            from LightlyDoped_Semiconductor
            to HeavilyDoped_Metallic
            when currentDopingLevel >= 0.1;

        transition t3
            from HeavilyDoped_Metallic
            to LightlyDoped_Semiconductor
            when currentDopingLevel < 0.1 and currentDopingLevel > 0.0;

        transition t4
            from LightlyDoped_Semiconductor
            to Undoped_Insulator
            when currentDopingLevel <= 0.0;

        transition t5
            from Undoped_Insulator
            to Degraded
            when currentTemperature > maxSafeTemperature or currentHumidity > maxSafeHumidity;

        transition t6
            from LightlyDoped_Semiconductor
            to Degraded
            when currentTemperature > maxSafeTemperature or currentHumidity > maxSafeHumidity;

        transition t7
            from HeavilyDoped_Metallic
            to Degraded
            when currentTemperature > maxSafeTemperature or currentHumidity > maxSafeHumidity;
    }

    // ================================================================
    // Action Definitions — Operational Process
    // ================================================================

    action def InitializeBasePolymer {
        doc /* Initialize a base polymer substrate before the doping process */;
        in chainLength : ChainLengthValue;
        in crystallinity : CrystallinityValue;
        in bandGap : BandGapValue;
        out polymer : PolymerChain;

        action selectPolymer {
            doc /* Select the polymer type and prepare the substrate */;
            out basePolymer : PolymerChain;
        }

        action verifyStructure {
            doc /* Verify the polymer chain structure and order */;
        }

        succession from selectPolymer to verifyStructure;
        flow from selectPolymer.basePolymer to verifyStructure;
    }

    action def ApplyDopant {
        doc /* Apply the correct amount of dopant to the polymer */;
        in polymer : PolymerChain;
        in dopant : DopantChemical;
        in targetLevel : DopingLevelValue;
        out dopedPolymer : PolymerChain;
        out achievedLevel : DopingLevelValue;

        action dispenseDopant {
            doc /* Dispense the dopant at a controlled rate */;
            in chemical : DopantChemical;
            in rate : DopantConcentrationValue;
        }

        action diffuseDopant {
            doc /* Allow the dopant to diffuse through the polymer matrix */;
            in time : TimeValue;
        }

        action measureDopingLevel {
            doc /* Measure the resulting doping level */;
            out level : DopingLevelValue;
        }

        succession from dispenseDopant to diffuseDopant;
        succession from diffuseDopant to measureDopingLevel;
    }

    action def StabilizeEnvironment {
        doc /* Stabilize the environmental conditions for the material */;
        in targetTemp : TemperatureValue;
        in targetHum : HumidityValue;
        out stabilizedTemp : TemperatureValue;
        out stabilizedHum : HumidityValue;

        action setTargets {
            doc /* Set the target temperature and humidity */;
            in temp : TemperatureValue;
            in hum : HumidityValue;
        }

        action waitForEquilibrium {
            doc /* Wait for environmental conditions to reach equilibrium */;
            in duration : TimeValue;
        }

        succession from setTargets to waitForEquilibrium;
    }

    action def ApplyVoltage {
        doc /* Apply a voltage across the electrodes to facilitate current flow */;
        in polymer : PolymerChain;
        in electrodeA : Electrode;
        in electrodeB : Electrode;
        in voltage : VoltageValue;
        out current : CurrentValue;
        out power : PowerValue;

        action connectElectrodes {
            doc /* Ensure the electrodes are properly connected to the polymer */;
            in anode : Electrode;
            in cathode : Electrode;
        }

        action rampVoltage {
            doc /* Gradually ramp the voltage to avoid a sudden current surge */;
            in target : VoltageValue;
            in rampTime : TimeValue;
        }

        action measureResponse {
            doc /* Measure the resulting current and power output */;
            out measuredCurrent : CurrentValue;
            out measuredPower : PowerValue;
        }

        succession from connectElectrodes to rampVoltage;
        succession from rampVoltage to measureResponse;
    }

    action def MonitorAndProtect {
        doc /* Continuously monitor the environment and protect the material from degradation */;
        in controller : EnvironmentalController;
        in maxTemp : TemperatureValue;
        in maxHum : HumidityValue;
        out alarm : Boolean;

        action readSensors {
            doc /* Read the temperature and humidity sensors */;
            out temp : TemperatureValue;
            out hum : HumidityValue;
        }

        action checkThresholds {
            doc /* Check whether the measured values exceed safe thresholds */;
            in temp : TemperatureValue;
            in hum : HumidityValue;
            out exceeded : Boolean;
        }

        action triggerAlarm {
            doc /* Trigger an alarm and initiate protective measures */;
        }

        succession from readSensors to checkThresholds;
        succession from checkThresholds to triggerAlarm;
    }

    // ================================================================
    // Main System Definition
    // ================================================================

    part def ConductivePolymer {
        doc /*
            Conductive polymer material system.
            A specialized type of plastic designed to conduct electricity
            through a controlled process of chemical doping. Used in
            applications such as flexible electronics, sensors, and
            energy storage devices where the mechanical properties of
            plastic are desired along with electrical conductivity.
        */;

        attribute materialName : String;
        attribute application : String;
        attribute maxOperatingTemperature : TemperatureValue = 80.0;
        attribute maxOperatingHumidity : HumidityValue = 90.0;
        attribute targetDopingLevel : DopingLevelValue = 0.15;
        attribute operatingVoltage : VoltageValue;
        attribute ratedCurrent : CurrentValue;
        attribute effectiveConductivity : ConductivityValue;
        attribute currentDopingState : DopingState = DopingState::undoped;
        attribute degradationMode : DegradationMode = DegradationMode::none;
        attribute initialized : Boolean = false;
        attribute stabilizationComplete : Boolean = false;
        attribute voltageApplied : Boolean = false;

        // ---- Component parts ----

        part polymer : PolymerChain {
            chainLength = 1000;
            crystallinity = 35.0;
            molarMass = 106000;
            bandGap = 1.5;
            baseConductivity = 1e-10;
            monomer.molarMass = 106.0;
            monomer.conjugationLength = 0.4;
        }

        part dopingSystem : DopingAgent {
            targetDopingLevel = 0.15;
            currentDopingLevel = 0.0;
            dopingTime = 300.0;
            dopantChemical.type = DopantType::oxidative;
            dopantChemical.molarMass = 122.0;
            dopantChemical.electronAffinity = 5.1;
            dopantChemical.concentration = 0.5;
        }

        part envController : EnvironmentalController {
            targetTemperature = 25.0;
            targetHumidity = 40.0;
            maxOperatingTemp = 80.0;
            minOperatingTemp = -20.0;
            maxOperatingHumidity = 90.0;
            minOperatingHumidity = 5.0;
            tolerance = 2.0;
            alarmActive = false;
        }

        part conduction : ConductionMechanism {
            mechanismType = ConductionMechanismType::none;
            effectiveConductivity = 0.0;
            carrierDensity = 0.0;
            carrierMobility = 0.5;
            chargeCarrier.carrierType = CarrierType::polaron;
            chargeCarrier.charge = 1.6e-19;
            chargeCarrier.mobility = 0.5;
            chargeCarrier.density = 0.0;
            dopingState = DopingState::undoped;
        }

        part anode : Electrode {
            role = ConductorRole::anode;
            material = "gold";
            surfaceArea = 1.0;
            contactResistance = 0.5;
            appliedVoltage = 0.0;
            measuredCurrent = 0.0;
        }

        part cathode : Electrode {
            role = ConductorRole::cathode;
            material = "gold";
            surfaceArea = 1.0;
            contactResistance = 0.5;
            appliedVoltage = 0.0;
            measuredCurrent = 0.0;
        }

        part carrierPopulation : ChargeCarrierPopulation {
            primaryCarrierType = CarrierType::polaron;
            density = 0.0;
            mobility = 0.5;
            totalCharge = 0.0;
            recombinationRate = 1e-4;
            generationRate = 0.0;
        }

        // ---- Ports ----

        port externalElectricalA : ElectricalPort;
        port externalElectricalB : ElectricalPort;
        port systemStatus : StatusPort;
        port externalControl : ControlPort;

        // ---- Internal connections ----

        connection dopantFlow connects dopingSystem.dopantOutput to polymer.chemicalEntry;
        connection envCoupling connects envController.environmentOutput to polymer.environmentInterface;
        connection anodePolymer connects anode.polymerContact to polymer.electrodeInterfaceA;
        connection cathodePolymer connects cathode.polymerContact to polymer.electrodeInterfaceB;
        connection envControl connects externalControl to envController.controlInput;
        connection envStatus connects envController.environmentStatus to systemStatus;
        connection dopingStatus connects dopingSystem.dopantStatus to systemStatus;
        connection mechStatus connects conduction.mechanismStatus to systemStatus;
        connection extElecA connects externalElectricalA to anode.electricalContact;
        connection extElecB connects externalElectricalB to cathode.electricalContact;

        // ---- State machine ----

        sm materialState : MaterialConductionState {
            currentDopingLevel = 0.0;
            currentTemperature = 25.0;
            currentHumidity = 40.0;
            maxSafeTemperature = 80.0;
            maxSafeHumidity = 90.0;
            degradedFlag = false;
        }

        // ---- Operational process ----

        action operationalProcess {
            doc /* Full operational process for the conductive polymer system */;

            action init : InitializeBasePolymer {
                chainLength = 1000;
                crystallinity = 35.0;
                bandGap = 1.5;
            }

            action dope : ApplyDopant {
                targetLevel = 0.15;
            }

            action stabilize : StabilizeEnvironment {
                targetTemp = 25.0;
                targetHum = 40.0;
            }

            action applyV : ApplyVoltage {
                voltage = 5.0;
            }

            succession from init to dope;
            succession from dope to stabilize;
            succession from stabilize to applyV;
            flow from init.polymer to dope.polymer;
            flow from dope.dopedPolymer to applyV.polymer;
        }

        // ---- Initialization ----

        action initialize {
            doc /* Initialize the entire conductive polymer system */;
            currentDopingState = DopingState::undoped;
            initialized = true;
            stabilizationComplete = false;
            voltageApplied = false;
        }

        // ---- Doping state determination ----

        action processDoping {
            doc /* Determine the doping state from the current doping level */;
            in level : DopingLevelValue;

            if level == 0.0 {
                currentDopingState = DopingState::undoped;
                conduction.mechanismType = ConductionMechanismType::none;
            }
            if level > 0.0 and level < 0.1 {
                currentDopingState = DopingState::lightlyDoped;
                conduction.mechanismType = ConductionMechanismType::hopping;
            }
            if level >= 0.1 {
                currentDopingState = DopingState::heavilyDoped;
                conduction.mechanismType = ConductionMechanismType::metallic;
            }
        }

        // ---- Degradation check ----

        action checkDegradation {
            doc /* Check whether the material has degraded under adverse conditions */;
            in temp : TemperatureValue;
            in hum : HumidityValue;

            if temp > maxOperatingTemperature or hum > maxOperatingHumidity {
                currentDopingState = DopingState::degraded;
                conduction.mechanismType = ConductionMechanismType::none;
                effectiveConductivity = 0.0;
                degradationMode = DegradationMode::thermalDegradation;
            }
        }
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def ConductivityAchievement {
        doc /* The doped polymer must achieve a target electrical conductivity */;
        attribute minConductivity : ConductivityValue = 1.0;
        attribute targetConductivity : ConductivityValue = 100.0;
        subject material : ConductivePolymer;
        predicate {
            material.effectiveConductivity >= minConductivity
        }
    }

    requirement def DopingProcessControl {
        doc /* The doping process must be precisely controlled within tolerance */;
        attribute dopingTolerance : DopingLevelValue = 0.01;
        attribute targetLevel : DopingLevelValue = 0.15;
        subject material : ConductivePolymer;
        predicate {
            material.dopingSystem.currentDopingLevel >= targetLevel - dopingTolerance
            and material.dopingSystem.currentDopingLevel <= targetLevel + dopingTolerance
        }
    }

    requirement def EnvironmentalStability {
        doc /* Environmental conditions must be maintained within safe operating bounds */;
        attribute maxTemp : TemperatureValue = 80.0;
        attribute minTemp : TemperatureValue = -20.0;
        attribute maxHum : HumidityValue = 90.0;
        attribute minHum : HumidityValue = 5.0;
        subject material : ConductivePolymer;
        predicate {
            material.envController.measuredTemperature <= maxTemp
            and material.envController.measuredTemperature >= minTemp
            and material.envController.measuredHumidity <= maxHum
            and material.envController.measuredHumidity >= minHum
        }
    }

    requirement def DegradationPrevention {
        doc /* The system must prevent material degradation under adverse conditions */;
        attribute alarmThresholdTemp : TemperatureValue = 75.0;
        attribute alarmThresholdHum : HumidityValue = 85.0;
        subject material : ConductivePolymer;
        predicate {
            material.currentDopingState != DopingState::degraded
        }
    }

    requirement def FlexibleElectronicsSuitability {
        doc /* The material must retain mechanical flexibility while conducting electricity */;
        attribute minChainLength : ChainLengthValue = 500;
        attribute minCrystallinity : CrystallinityValue = 20.0;
        subject material : ConductivePolymer;
        predicate {
            material.polymer.chainLength >= minChainLength
            and material.polymer.crystallinity >= minCrystallity
        }
    }

    requirement def VoltageApplication {
        doc /* The system must apply voltage across its electrodes to facilitate current flow */;
        attribute minVoltage : VoltageValue = 0.1;
        attribute maxVoltage : VoltageValue = 10.0;
        subject material : ConductivePolymer;
        predicate {
            material.operatingVoltage >= minVoltage
            and material.operatingVoltage <= maxVoltage
        }
    }

    requirement def CarrierGeneration {
        doc /* The doping process must create mobile charge carriers in the polymer */;
        attribute minCarrierDensity : CarrierDensityValue = 1e16;
        subject material : ConductivePolymer;
        predicate {
            material.conduction.carrierDensity >= minCarrierDensity
        }
    }

    requirement def OperationalProcessSequence {
        doc /*
            The operational process must follow the correct sequence:
            initialize the base polymer, apply the correct amount of dopant,
            stabilize the environmental conditions, and then apply a voltage.
        */;
        subject material : ConductivePolymer;
        predicate {
            material.initialized
            and material.dopingSystem.currentDopingLevel > 0.0
            and material.stabilizationComplete
            and material.voltageApplied
        }
    }

    // ================================================================
    // Requirement Satisfaction
    // ================================================================

    satisfy ConductivityAchievement {
        subject material : ConductivePolymer;
    }

    satisfy DopingProcessControl {
        subject material : ConductivePolymer;
    }

    satisfy EnvironmentalStability {
        subject material : ConductivePolymer;
    }

    satisfy DegradationPrevention {
        subject material : ConductivePolymer;
    }

    satisfy FlexibleElectronicsSuitability {
        subject material : ConductivePolymer;
    }

    satisfy VoltageApplication {
        subject material : ConductivePolymer;
    }

    satisfy CarrierGeneration {
        subject material : ConductivePolymer;
    }

    satisfy OperationalProcessSequence {
        subject material : ConductivePolymer;
    }

}
