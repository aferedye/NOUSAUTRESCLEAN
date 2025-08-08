<?php
namespace App\Command;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(name: 'app:seed-user')]
class SeedUserCommand extends Command
{
    public function __construct(
        private EntityManagerInterface $em,
        private UserPasswordHasherInterface $hasher
    ) { parent::__construct(); }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $email = 'demo@example.com';
        $plain = 'Azerty123!';
        $repo = $this->em->getRepository(User::class);
        $u = $repo->findOneBy(['email' => $email]) ?? new User();
        $u->setEmail($email);
        $u->setPassword($this->hasher->hashPassword($u, $plain));
        $this->em->persist($u);
        $this->em->flush();
        $output->writeln('Seed OK: '.$email.' / '.$plain);
        return Command::SUCCESS;
    }
}