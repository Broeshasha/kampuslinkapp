class University {
  final int id;
  final String name;
  final String city;
  const University(this.id, this.name, this.city);
}

// Mirrors the `universities` table in Supabase — id values must match exactly.
// Update both together if this list ever changes.
const algeriaUniversities = [
  University(1, 'University of Ahmed Draia', 'Adrar'),
  University(2, 'Djilali Bounaama University', 'Khemis Miliana'),
  University(3, 'Belhadj Bouchaib University Centre', 'Ain Témouchent'),
  University(4, 'University of Algiers (Benyoucef Benkhedda)', 'Algiers'),
  University(5, 'University of Science and Technology Houari Boumediene', 'Algiers'),
  University(6, 'Badji Mokhtar Annaba University', 'Annaba'),
  University(7, 'Batna 1 University (Hadj Lakhdar)', 'Batna'),
  University(8, 'Batna 2 University (Mostefa Ben Boulaid)', 'Batna'),
  University(9, 'University of Tahri Mohammed', 'Béchar'),
  University(10, 'University of Béjaïa (Abderrahmane Mira)', 'Béjaïa'),
  University(11, 'University of Biskra (Mohamed Khider)', 'Biskra'),
  University(12, 'Blida 1 University (Saad Dahlab)', 'Blida'),
  University(13, 'University of Bordj Bou Arréridj', 'Bordj Bou Arréridj'),
  University(14, 'University of Bouïra (Akli Mohand Oulhadj)', 'Bouïra'),
  University(15, 'University of Boumerdès (M\'hamed Bougara)', 'Boumerdès'),
  University(16, 'University of Chlef (Hassiba Benbouali)', 'Chlef'),
  University(17, 'Constantine 1 University (Mentouri)', 'Constantine'),
  University(18, 'Constantine 2 University (Abdelhamid Mehri)', 'Constantine'),
  University(19, 'University of Mila', 'Mila'),
  University(20, 'Ziane Achour University', 'Djelfa'),
  University(21, 'University Center of El Bayadh', 'El Bayadh'),
  University(22, 'University of El Oued', 'El Oued'),
  University(23, 'University of El Taref', 'El Taref'),
  University(24, 'University of Ghardaïa', 'Ghardaïa'),
  University(25, 'University of Guelma', 'Guelma'),
  University(26, 'University Center of Illizi', 'Illizi'),
  University(27, 'University of Jijel', 'Jijel'),
  University(28, 'University of Khenchela', 'Khenchela'),
  University(29, 'University of Laghouat', 'Laghouat'),
  University(30, 'University of Mascara', 'Mascara'),
  University(31, 'University of Medea', 'Médéa'),
  University(32, 'University of Mostaganem', 'Mostaganem'),
  University(33, 'University of M\'Sila', 'M\'Sila'),
  University(34, 'University Center of Naama', 'Naâma'),
  University(35, 'University of Oran 1 (Ahmed Ben Bella)', 'Oran'),
  University(36, 'University of Oran 2 (Mohamed Ben Ahmed)', 'Oran'),
  University(37, 'University of Science and Technology Mohamed Boudiaf', 'Oran'),
  University(38, 'University of Ouargla', 'Ouargla'),
  University(39, 'Larbi Ben M\'hidi University', 'Oum El Bouaghi'),
  University(40, 'University Center of Relizane', 'Relizane'),
  University(41, 'University of Saïda', 'Saïda'),
  University(42, 'Sétif 1 University (Ferhat Abbas)', 'Sétif'),
  University(43, 'Djillali Liabes University', 'Sidi Bel Abbès'),
  University(44, 'University of Skikda', 'Skikda'),
  University(45, 'University of Souk Ahras', 'Souk Ahras'),
  University(46, 'University of Tamanrasset', 'Tamanrasset'),
  University(47, 'Echahid Cheikh Larbi Tebessi University', 'Tébessa'),
  University(48, 'University of Tiaret', 'Tiaret'),
  University(49, 'University Center of Tindouf', 'Tindouf'),
  University(50, 'Abdallah Morsli University Center', 'Tipaza'),
  University(51, 'Ahmed Ben Yahia Al Wancharissi University Center', 'Tissemsilt'),
  University(52, 'Mouloud Mammeri University', 'Tizi Ouzou'),
  University(53, 'University of Tlemcen', 'Tlemcen'),
];

class Speciality {
  final int id;
  final String name;
  const Speciality(this.id, this.name);
}

const algeriaSpecialities = [
  Speciality(1, 'Computer Science'),
  Speciality(2, 'Mining Engineering'),
  Speciality(3, 'Civil Engineering'),
  Speciality(4, 'Electrical Engineering'),
  Speciality(5, 'Mechanical Engineering'),
  Speciality(6, 'Medicine'),
  Speciality(7, 'Pharmacy'),
  Speciality(8, 'Dentistry'),
  Speciality(9, 'Nursing / Paramedical'),
  Speciality(10, 'Law'),
  Speciality(11, 'Business & Economics'),
  Speciality(12, 'Accounting & Finance'),
  Speciality(13, 'Architecture'),
  Speciality(14, 'Agronomy'),
  Speciality(15, 'Biology'),
  Speciality(16, 'Chemistry'),
  Speciality(17, 'Physics'),
  Speciality(18, 'Mathematics'),
  Speciality(19, 'Arabic Literature'),
  Speciality(20, 'French Literature'),
  Speciality(21, 'English Literature / Translation'),
  Speciality(22, 'Journalism & Communication'),
  Speciality(23, 'Political Science'),
  Speciality(24, 'Sociology & Psychology'),
  Speciality(25, 'Telecommunications'),
  Speciality(26, 'Petroleum Engineering'),
  Speciality(27, 'Other'),
];