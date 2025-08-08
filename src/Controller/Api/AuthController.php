<?php

namespace App\Controller\Api;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/v1/auth')]
class AuthController extends AbstractController
{
    #[Route('/register', name: 'api_register', methods: ['POST'])]
    public function register(
        Request $request,
        EntityManagerInterface $em,
        UserPasswordHasherInterface $hasher
    ): JsonResponse {
        $data = json_decode($request->getContent(), true) ?? [];
        $email = isset($data['email']) ? trim((string)$data['email']) : '';
        $password = isset($data['password']) ? (string)$data['password'] : '';

        if ($email === '' || $password === '') {
            return $this->json(['error' => 'email and password are required'], 422);
        }

        try {
            $existing = $em->getRepository(User::class)->findOneBy(['email' => strtolower($email)]);
            if ($existing) {
                return $this->json(['error' => 'email already registered'], 409);
            }

            $user = new User();
            $user->setEmail($email);
            $user->setPassword($hasher->hashPassword($user, $password));
            $em->persist($user);
            $em->flush();

            return $this->json(['id' => $user->getId(), 'email' => $user->getEmail()], 201);
        } catch (\Throwable $e) {
            $isDev = ($_ENV['APP_ENV'] ?? 'prod') === 'dev';
            $payload = ['error' => 'register_failed'];
            if ($isDev) {
                $payload['message'] = $e->getMessage();
                if ($p = $e->getPrevious()) {
                    $payload['previous'] = ['type' => (new \ReflectionClass($p))->getShortName(), 'message' => $p->getMessage()];
                }
            }
            return $this->json($payload, 500);
        }
    }

    #[Route('/me', name: 'api_me', methods: ['GET'])]
    public function me(): JsonResponse
    {
        $u = $this->getUser();
        return $this->json([
            'email' => $u?->getUserIdentifier(),
            'roles' => $u?->getRoles(),
        ]);
    }
}