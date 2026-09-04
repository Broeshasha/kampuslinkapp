class University {
  final int id;
  final String name;
  final String city;
  final int wilayaId; // FK to `wilayas` — drives the residence picker
  const University(this.id, this.name, this.city, this.wilayaId);
}

// Mirrors the `universities` table in Supabase — id values must match exactly.
// Update both together if this list ever changes.
const algeriaUniversities = [
  University(1, 'University of Ahmed Draia', 'Adrar', 1),
  University(2, 'Djilali Bounaama University', 'Khemis Miliana', 44),
  University(3, 'Belhadj Bouchaib University Centre', 'Ain Témouchent', 46),
  University(4, 'University of Algiers (Benyoucef Benkhedda)', 'Algiers', 16),
  University(5, 'University of Science and Technology Houari Boumediene', 'Algiers', 16),
  University(6, 'Badji Mokhtar Annaba University', 'Annaba', 23),
  University(7, 'Batna 1 University (Hadj Lakhdar)', 'Batna', 5),
  University(8, 'Batna 2 University (Mostefa Ben Boulaid)', 'Batna', 5),
  University(9, 'University of Tahri Mohammed', 'Béchar', 8),
  University(10, 'University of Béjaïa (Abderrahmane Mira)', 'Béjaïa', 6),
  University(11, 'University of Biskra (Mohamed Khider)', 'Biskra', 7),
  University(12, 'Blida 1 University (Saad Dahlab)', 'Blida', 9),
  University(13, 'University of Bordj Bou Arréridj', 'Bordj Bou Arréridj', 34),
  University(14, 'University of Bouïra (Akli Mohand Oulhadj)', 'Bouïra', 10),
  University(15, 'University of Boumerdès (M\'hamed Bougara)', 'Boumerdès', 35),
  University(16, 'University of Chlef (Hassiba Benbouali)', 'Chlef', 2),
  University(17, 'Constantine 1 University (Mentouri)', 'Constantine', 25),
  University(18, 'Constantine 2 University (Abdelhamid Mehri)', 'Constantine', 25),
  University(19, 'University of Mila', 'Mila', 43),
  University(20, 'Ziane Achour University', 'Djelfa', 17),
  University(21, 'University Center of El Bayadh', 'El Bayadh', 32),
  University(22, 'University of El Oued', 'El Oued', 39),
  University(23, 'University of El Taref', 'El Taref', 36),
  University(24, 'University of Ghardaïa', 'Ghardaïa', 47),
  University(25, 'University of Guelma', 'Guelma', 24),
  University(26, 'University Center of Illizi', 'Illizi', 33),
  University(27, 'University of Jijel', 'Jijel', 18),
  University(28, 'University of Khenchela', 'Khenchela', 40),
  University(29, 'University of Laghouat', 'Laghouat', 3),
  University(30, 'University of Mascara', 'Mascara', 29),
  University(31, 'University of Medea', 'Médéa', 26),
  University(32, 'University of Mostaganem', 'Mostaganem', 27),
  University(33, 'University of M\'Sila', 'M\'Sila', 28),
  University(34, 'University Center of Naama', 'Naâma', 45),
  University(35, 'University of Oran 1 (Ahmed Ben Bella)', 'Oran', 31),
  University(36, 'University of Oran 2 (Mohamed Ben Ahmed)', 'Oran', 31),
  University(37, 'University of Science and Technology Mohamed Boudiaf', 'Oran', 31),
  University(38, 'University of Ouargla', 'Ouargla', 30),
  University(39, 'Larbi Ben M\'hidi University', 'Oum El Bouaghi', 4),
  University(40, 'University Center of Relizane', 'Relizane', 48),
  University(41, 'University of Saïda', 'Saïda', 20),
  University(42, 'Sétif 1 University (Ferhat Abbas)', 'Sétif', 19),
  University(43, 'Djillali Liabes University', 'Sidi Bel Abbès', 22),
  University(44, 'University of Skikda', 'Skikda', 21),
  University(45, 'University of Souk Ahras', 'Souk Ahras', 41),
  University(46, 'University of Tamanrasset', 'Tamanrasset', 11),
  University(47, 'Echahid Cheikh Larbi Tebessi University', 'Tébessa', 12),
  University(48, 'University of Tiaret', 'Tiaret', 14),
  University(49, 'University Center of Tindouf', 'Tindouf', 37),
  University(50, 'Abdallah Morsli University Center', 'Tipaza', 42),
  University(51, 'Ahmed Ben Yahia Al Wancharissi University Center', 'Tissemsilt', 38),
  University(52, 'Mouloud Mammeri University', 'Tizi Ouzou', 15),
  University(53, 'University of Tlemcen', 'Tlemcen', 13),
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
