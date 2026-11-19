import PeopleController from "./people.gjs";
import profileDirectoryController from "../lib/svdex-profile-directory-controller.gjs";
export default class IndependentPeopleController extends profileDirectoryController(PeopleController, "people") {}
