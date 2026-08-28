package OlfactometerSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def Air;
        item def OdorantVapor;
        item def ScentedAir;

        attribute def ConcentrationValue :> Real;
        attribute def DurationValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def HumidityValue :> Real;
        attribute def FlowRateValue :> Real;

        part def FilteredAirSupply {
            port airOut {
                out air : Air;
            }
        }

        part def HumidityController {
            port airIn {
                in air : Air;
            }
            port airOut {
                out air : Air;
            }
            attribute humiditySetpoint : HumidityValue;
        }

        part def TemperatureController {
            port airIn {
                in air : Air;
            }
            port airOut {
                out air : Air;
            }
            attribute tempSetpoint : TemperatureValue;
        }

        part def OdorantReservoir {
            attribute odorantId : String;
            port vaporOut {
                out vapor : OdorantVapor;
            }
        }

        part def MassFlowController {
            port cmdIn {
                in cmd : FlowRateValue;
            }
            attribute flowRate : FlowRateValue;
        }

        part def AirMFC :> MassFlowController {
            port fluidIn {
                in air : Air;
            }
            port fluidOut {
                out air : Air;
            }
        }

        part def VaporMFC :> MassFlowController {
            port fluidIn {
                in vapor : OdorantVapor;
            }
            port fluidOut {
                out vapor : OdorantVapor;
            }
        }

        part def MixingManifold {
            port carrierIn {
                in air : Air;
            }
            port vaporIn {
                in vapor : OdorantVapor;
            }
            port mixedOut {
                out mixed : ScentedAir;
            }
        }

        part def ConcentrationSensor {
            port airIn {
                in air : ScentedAir;
            }
            port measurementOut {
                out measurement : ConcentrationValue;
            }
        }

        part def ControlComputer {
            port concentrationFeedback {
                in measurement : ConcentrationValue;
            }
            port mfcCommand {
                out cmd : FlowRateValue;
            }
            attribute targetConcentration : ConcentrationValue;
            attribute targetDuration : DurationValue;
        }

        action def StimulusProtocol {
            in targetConc : ConcentrationValue;
            in duration : DurationValue;
            action stabilize;
            action deliver;
            action purge;
            first start;
            then stabilize;
            then deliver;
            then purge;
            then finish;
        }

        state def OlfactometerOperation {
            state idle;
            state stabilizing;
            state delivering;
            state purging;
            transition from idle to stabilizing;
            transition from stabilizing to delivering;
            transition from delivering to purging;
            transition from purging to idle;
        }

        part def Olfactometer {
            part airSupply : FilteredAirSupply;
            part humidityCtrl : HumidityController;
            part tempCtrl : TemperatureController;
            part reservoirs[4] : OdorantReservoir;
            part mfcAir : AirMFC;
            part mfcVapor[4] : VaporMFC;
            part manifold : MixingManifold;
            part sensor : ConcentrationSensor;
            part computer : ControlComputer;

            flow airFlow1 of Air from airSupply.airOut.air to humidityCtrl.airIn.air;
            flow airFlow2 of Air from humidityCtrl.airOut.air to tempCtrl.airIn.air;
            flow airFlow3 of Air from tempCtrl.airOut.air to mfcAir.fluidIn.air;
            flow airFlow4 of Air from mfcAir.fluidOut.air to manifold.carrierIn.air;

            flow vaporFlow1 of OdorantVapor from reservoirs[1].vaporOut.vapor to mfcVapor[1].fluidIn.vapor;
            flow vaporFlow2 of OdorantVapor from reservoirs[2].vaporOut.vapor to mfcVapor[2].fluidIn.vapor;
            flow vaporFlow3 of OdorantVapor from reservoirs[3].vaporOut.vapor to mfcVapor[3].fluidIn.vapor;
            flow vaporFlow4 of OdorantVapor from reservoirs[4].vaporOut.vapor to mfcVapor[4].fluidIn.vapor;

            flow vaporMfcFlow1 of OdorantVapor from mfcVapor[1].fluidOut.vapor to manifold.vaporIn.vapor;
            flow vaporMfcFlow2 of OdorantVapor from mfcVapor[2].fluidOut.vapor to manifold.vaporIn.vapor;
            flow vaporMfcFlow3 of OdorantVapor from mfcVapor[3].fluidOut.vapor to manifold.vaporIn.vapor;
            flow vaporMfcFlow4 of OdorantVapor from mfcVapor[4].fluidOut.vapor to manifold.vaporIn.vapor;

            flow mixedAirFlow of ScentedAir from manifold.mixedOut.mixed to sensor.airIn.air;

            flow feedbackFlow of ConcentrationValue from sensor.measurementOut.measurement to computer.concentrationFeedback.measurement;
            flow cmdFlow1 of FlowRateValue from computer.mfcCommand.cmd to mfcAir.cmdIn.cmd;
            flow cmdFlow2 of FlowRateValue from computer.mfcCommand.cmd to mfcVapor[1].cmdIn.cmd;
            flow cmdFlow3 of FlowRateValue from computer.mfcCommand.cmd to mfcVapor[2].cmdIn.cmd;
            flow cmdFlow4 of FlowRateValue from computer.mfcCommand.cmd to mfcVapor[3].cmdIn.cmd;
            flow cmdFlow5 of FlowRateValue from computer.mfcCommand.cmd to mfcVapor[4].cmdIn.cmd;

            state operationState : OlfactometerOperation;
        }
    }

    package Requirements {
        private import Definitions::ConcentrationValue;
        private import ScalarValues::Integer;

        requirement def ConcentrationAccuracy {
            doc /* The system shall deliver odorant at the target concentration within +/- 5%. */
            attribute target : ConcentrationValue;
            attribute actual : ConcentrationValue;
        }

        requirement def MultiChannelSupport {
            doc /* The system shall support up to 4 independent odorant channels. */
            attribute numChannels : Integer = 4;
        }

        requirement def PurgeCapability {
            doc /* The system shall purge residual scent between trials. */
        }

        requirement olfactometerRequirements {
            requirement concentrationAccuracy : ConcentrationAccuracy;
            requirement multiChannelSupport : MultiChannelSupport;
            requirement purgeCapability : PurgeCapability;
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part olfactometer : Olfactometer {
            satisfy olfactometerRequirements;
        }
    }
}
