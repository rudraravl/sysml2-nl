package GasolineEngine {

    import ScalarValues::*;

    // ===== VALUE TYPES =====

    attribute def Pressure :> Real {
        doc "Pressure in Pascals";
    }

    attribute def FuelPressure :> Real {
        doc "Fuel pressure in bar";
    }

    attribute def Volume :> Real {
        doc "Volume in liters";
    }

    attribute def Temperature :> Real {
        doc "Temperature in Kelvin";
    }

    attribute def MassFlowRate :> Real {
        doc "Mass flow rate in kilograms per second";
    }

    attribute def VolumetricFlowRate :> Real {
        doc "Volumetric flow rate in cubic meters per second";
    }

    attribute def Voltage :> Real {
        doc "Electrical voltage in volts";
    }

    attribute def TorqueValue :> Real {
        doc "Torque in Newton-meters";
    }

    attribute def PowerValue :> Real {
        doc "Power in watts";
    }

    attribute def RotationalSpeed :> Real {
        doc "Rotational speed in revolutions per minute";
    }

    attribute def Ratio :> Real {
        doc "Dimensionless ratio";
    }

    attribute def Efficiency :> Real {
        doc "Conversion efficiency between 0 and 1";
    }

    attribute def Mass :> Real {
        doc "Mass in kilograms";
    }

    // ===== ITEM DEFINITIONS =====

    item def Gasoline {
        doc "Chemical fuel stored in the fuel tank";
        attribute octaneRating : Real;
        attribute energyDensity : PowerValue;
    }

    item def AtmosphericAir {
        doc "Unfiltered air drawn from the atmosphere";
        attribute oxygenFraction : Real;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def CleanAir :> AtmosphericAir {
        doc "Atmospheric air after passing through the air filter";
        attribute particulateRemoved : Real;
    }

    item def ThrottledAir :> CleanAir {
        doc "Clean air after passing through the throttle valve";
        attribute flowRate : VolumetricFlowRate;
        attribute throttlePosition : Ratio;
    }

    item def FuelMist {
        doc "Gasoline sprayed as a fine mist by the fuel injector";
        attribute dropletDiameter : Real;
        attribute massFlow : MassFlowRate;
    }

    item def AirFuelMixture {
        doc "Combination of throttled air and fuel mist";
        attribute air : ThrottledAir;
        attribute fuel : FuelMist;
        attribute airFuelRatio : Ratio;
    }

    item def CompressedMixture :> AirFuelMixture {
        doc "Air-fuel mixture after compression in the cylinder";
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def ExhaustGas {
        doc "Hot spent gases resulting from combustion";
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute carbonMonoxide : Mass;
        attribute nitrogenOxides : Mass;
        attribute unburnedHydrocarbons : Mass;
    }

    item def TreatedExhaust :> ExhaustGas {
        doc "Exhaust gas after catalytic conversion";
    }

    item def HighVoltageSpark {
        doc "High-voltage electrical spark used to ignite the air-fuel mixture";
        attribute voltage : Voltage;
        attribute duration : Real;
    }

    item def MechanicalPower {
        doc "Mechanical power output from the engine";
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeed;
    }

    // ===== PORT DEFINITIONS =====

    port def FluidFlowPort {
        doc "Generic fluid flow port";
    }

    port def FuelInFlowPort :> FluidFlowPort {
        in item fuel : Gasoline;
    }

    port def FuelOutFlowPort :> FluidFlowPort {
        out item fuel : Gasoline;
    }

    port def FuelMistOutPort :> FluidFlowPort {
        out item mist : FuelMist;
    }

    port def FuelMistInPort :> FluidFlowPort {
        in item mist : FuelMist;
    }

    port def AirInPort :> FluidFlowPort {
        in item air : AtmosphericAir;
    }

    port def CleanAirOutPort :> FluidFlowPort {
        out item air : CleanAir;
    }

    port def CleanAirInPort :> FluidFlowPort {
        in item air : CleanAir;
    }

    port def ThrottledAirOutPort :> FluidFlowPort {
        out item air : ThrottledAir;
    }

    port def ThrottledAirInPort :> FluidFlowPort {
        in item air : ThrottledAir;
    }

    port def ExhaustInPort :> FluidFlowPort {
        in item gas : ExhaustGas;
    }

    port def ExhaustOutPort :> FluidFlowPort {
        out item gas : ExhaustGas;
    }

    port def SparkOutPort {
        out item spark : HighVoltageSpark;
    }

    port def SparkInPort {
        in item spark : HighVoltageSpark;
    }

    port def PowerOutPort {
        out item power : MechanicalPower;
    }

    // ===== PART DEFINITIONS =====

    part def Piston {
        doc "Cylindrical component that moves up and down within the combustion chamber";
        attribute position : Real;
        attribute atTopDeadCenter : Boolean;
        attribute atBottomDeadCenter : Boolean;
    }

    part def FuelTank {
        doc "Stores gasoline for the engine";
        port fuelOut : FuelOutFlowPort;
        attribute capacity : Volume = 50.0;
        attribute currentLevel : Volume;

        action def dispense {
            in item fuel : Gasoline;
            out item dispensed : Gasoline;
        }
    }

    part def FuelPump {
        doc "Draws fuel from the tank and pressurizes it for delivery to the injectors";
        port fuelIn : FuelInFlowPort;
        port fuelOut : FuelOutFlowPort;
        attribute outputPressure : FuelPressure = 3.5;
        attribute flowRate : MassFlowRate;

        action def pressurize {
            in item fuel : Gasoline;
            out item pressurizedFuel : Gasoline;
        }
    }

    part def FuelInjector {
        doc "Sprays a precise amount of fuel as a fine mist into the combustion chamber";
        port fuelIn : FuelInFlowPort;
        port mistOut : FuelMistOutPort;
        attribute injectionRate : MassFlowRate;
        attribute dutyCycle : Ratio;

        action def inject {
            in item fuel : Gasoline;
            out item mist : FuelMist;
        }
    }

    part def FuelSystem {
        doc "Manages fuel storage, pressurization, and injection for four cylinders";

        part tank : FuelTank;
        part pump : FuelPump;
        part injectors : FuelInjector[4];

        connection tankToPump connect tank.fuelOut to pump.fuelIn;
        connection pumpToInjector0 connect pump.fuelOut to injectors[0].fuelIn;
        connection pumpToInjector1 connect pump.fuelOut to injectors[1].fuelIn;
        connection pumpToInjector2 connect pump.fuelOut to injectors[2].fuelIn;
        connection pumpToInjector3 connect pump.fuelOut to injectors[3].fuelIn;
    }

    part def AirFilter {
        doc "Cleans atmospheric air of debris and particulate matter before it enters the throttle";
        port airIn : AirInPort;
        port airOut : CleanAirOutPort;

        action def filterAir {
            in item dirtyAir : AtmosphericAir;
            out item cleanAir : CleanAir;
        }
    }

    part def Throttle {
        doc "Valve that controls the volume of air entering the engine, thereby regulating power output";
        port airIn : CleanAirInPort;
        port airOut : ThrottledAirOutPort;
        attribute throttlePosition : Ratio;

        action def regulate {
            in item air : CleanAir;
            out item throttled : ThrottledAir;
        }
    }

    part def AirIntakeSystem {
        doc "Draws in atmospheric air, filters it, and regulates its flow through the throttle";

        part filter : AirFilter;
        part throttle : Throttle;

        connection filterToThrottle connect filter.airOut to throttle.airIn;
    }

    part def IgnitionSystem {
        doc "Generates high-voltage sparks to ignite the compressed air-fuel mixture in each cylinder";
        port sparkOut : SparkOutPort[4];
        attribute sparkVoltage : Voltage = 30000.0;
        attribute timingAdvance : RotationalSpeed;

        action def generateSpark {
            out item spark : HighVoltageSpark;
        }
    }

    part def CombustionChamber {
        doc "Cylinder where the four-stroke combustion cycle takes place";

        port airIn : ThrottledAirInPort;
        port fuelIn : FuelMistInPort;
        port sparkIn : SparkInPort;
        port exhaustOut : ExhaustOutPort;
        port powerOut : PowerOutPort;

        part piston : Piston;
        attribute cylinderNumber : Integer;
        attribute compressionRatio : Ratio = 10.0;
        attribute displacement : Volume;
        attribute crankAngle : Real = 0.0;
        attribute sparkReceived : Boolean = false;

        state fourStrokeCycle {
            state Intake {
                doc "Fuel-air mixture is drawn into the cylinder as the piston moves down";
                entry action { crankAngle = 0.0; }
            }
            state Compression {
                doc "Piston moves up, compressing the air-fuel mixture to high pressure";
                entry action { crankAngle = 180.0; }
            }
            state Power {
                doc "Spark ignites the compressed mixture, forcing the piston down with great force";
                entry action { crankAngle = 360.0; }
            }
            state Exhaust {
                doc "Piston moves back up, pushing hot spent gases out of the cylinder";
                entry action { crankAngle = 540.0; }
            }
            transition from Intake to Compression;
            transition from Compression to Power;
            transition from Power to Exhaust;
            transition from Exhaust to Intake;
        }
    }

    part def ExhaustManifold {
        doc "Collects hot exhaust gases from all four cylinders and funnels them into a single stream";
        port exhaustIn : ExhaustInPort[4];
        port exhaustOut : ExhaustOutPort;

        action def collect {
            in item gas1 : ExhaustGas;
            in item gas2 : ExhaustGas;
            in item gas3 : ExhaustGas;
            in item gas4 : ExhaustGas;
            out item combined : ExhaustGas;
        }
    }

    part def CatalyticConverter {
        doc "Uses chemical catalysts to transform harmful pollutants into less harmful substances";
        port exhaustIn : ExhaustInPort;
        port exhaustOut : ExhaustOutPort;

        attribute conversionEfficiencyCO : Efficiency = 0.95;
        attribute conversionEfficiencyNOx : Efficiency = 0.92;
        attribute conversionEfficiencyHC : Efficiency = 0.95;

        action def convert {
            in item rawGas : ExhaustGas;
            out item treatedGas : TreatedExhaust;
        }
    }

    part def ExhaustSystem {
        doc "Manages waste gases from combustion through collection and catalytic treatment";

        part manifold : ExhaustManifold;
        part converter : CatalyticConverter;

        connection manifoldToConverter connect manifold.exhaustOut to converter.exhaustIn;
    }

    part def Engine {
        doc "Complete gasoline-powered four-cylinder internal combustion engine";

        part fuelSystem : FuelSystem;
        part airIntake : AirIntakeSystem;
        part ignition : IgnitionSystem;
        part cylinders : CombustionChamber[4];
        part exhaustSystem : ExhaustSystem;

        connection airToCylinder0 connect airIntake.throttle.airOut to cylinders[0].airIn;
        connection airToCylinder1 connect airIntake.throttle.airOut to cylinders[1].airIn;
        connection airToCylinder2 connect airIntake.throttle.airOut to cylinders[2].airIn;
        connection airToCylinder3 connect airIntake.throttle.airOut to cylinders[3].airIn;

        connection fuelToCylinder0 connect fuelSystem.injectors[0].mistOut to cylinders[0].fuelIn;
        connection fuelToCylinder1 connect fuelSystem.injectors[1].mistOut to cylinders[1].fuelIn;
        connection fuelToCylinder2 connect fuelSystem.injectors[2].mistOut to cylinders[2].fuelIn;
        connection fuelToCylinder3 connect fuelSystem.injectors[3].mistOut to cylinders[3].fuelIn;

        connection sparkToCylinder0 connect ignition.sparkOut[0] to cylinders[0].sparkIn;
        connection sparkToCylinder1 connect ignition.sparkOut[1] to cylinders[1].sparkIn;
        connection sparkToCylinder2 connect ignition.sparkOut[2] to cylinders[2].sparkIn;
        connection sparkToCylinder3 connect ignition.sparkOut[3] to cylinders[3].sparkIn;

        connection exhaustFromCylinder0 connect cylinders[0].exhaustOut to exhaustSystem.manifold.exhaustIn[0];
        connection exhaustFromCylinder1 connect cylinders[1].exhaustOut to exhaustSystem.manifold.exhaustIn[1];
        connection exhaustFromCylinder2 connect cylinders[2].exhaustOut to exhaustSystem.manifold.exhaustIn[2];
        connection exhaustFromCylinder3 connect cylinders[3].exhaustOut to exhaustSystem.manifold.exhaustIn[3];

        attribute compressionRatio : Ratio = 10.0;
        attribute ratedPower : PowerValue = 90000.0;
        attribute ratedTorque : TorqueValue = 160.0;
        attribute maxRpm : RotationalSpeed = 6500.0;
        attribute cylinderCount : Integer = 4;
    }

    // ===== REQUIREMENTS =====

    requirement def CompressionRatioRequirement {
        doc "The engine shall have a compression ratio of 10:1";
        subject engine : Engine;
        attribute requiredCompressionRatio : Ratio = 10.0;
        require constraint { engine.compressionRatio == requiredCompressionRatio }
    }

    requirement def FuelPressureRequirement {
        doc "The fuel system shall deliver fuel at a pressure between 3.0 and 5.0 bar";
        subject engine : Engine;
        attribute minPressure : FuelPressure = 3.0;
        attribute maxPressure : FuelPressure = 5.0;
        require constraint {
            engine.fuelSystem.pump.outputPressure >= minPressure
            and engine.fuelSystem.pump.outputPressure <= maxPressure
        }
    }

    requirement def EmissionsControlRequirement {
        doc "The catalytic converter shall reduce carbon monoxide and nitrogen oxides by at least 90 percent";
        subject engine : Engine;
        attribute requiredReduction : Efficiency = 0.90;
        require constraint {
            engine.exhaustSystem.converter.conversionEfficiencyCO >= requiredReduction
            and engine.exhaustSystem.converter.conversionEfficiencyNOx >= requiredReduction
        }
    }

    requirement def PowerOutputRequirement {
        doc "The engine shall produce at least 90 kilowatts of mechanical power";
        subject engine : Engine;
        attribute minPower : PowerValue = 90000.0;
        require constraint { engine.ratedPower >= minPower }
    }

    requirement def FourCylinderRequirement {
        doc "The engine shall be a four-cylinder configuration";
        subject engine : Engine;
        attribute requiredCylinderCount : Integer = 4;
        require constraint { engine.cylinderCount == requiredCylinderCount }
    }
}
